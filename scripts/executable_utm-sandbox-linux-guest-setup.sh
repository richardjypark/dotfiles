#!/usr/bin/env bash
set -euo pipefail

CONFIRMED_VM=false
DRY_RUN=false
INSTALL_PACKAGES=true
WRITE_HELPERS=true

usage() {
    cat <<'EOF'
Usage: utm-sandbox-linux-guest-setup.sh --inside-unsafe-vm [options]

Prepare a Debian/Ubuntu Linux UTM guest for unsafe-file triage and document
sanitization. Run this inside a clean Linux VM template, not on the main Mac and
not on a trusted daily-driver Linux host.

Required:
  --inside-unsafe-vm     Acknowledge that this is running inside the disposable
                         or template UTM guest intended for unsafe work.

Options:
  --dry-run              Print commands that would run.
  --no-install           Create folders/helper notes without apt package install.
  --no-helpers           Do not write helper scripts under ~/bin.
  -h, --help             Show this help.

Safety:
  This script installs guest packages and writes files only inside the Linux VM.
  It does not configure UTM host sharing, clipboard, USB, networking, or any Mac
  host setting. Keep raw files inside the VM until sanitized.
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        printf 'Would run:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --inside-unsafe-vm)
            CONFIRMED_VM=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --no-install)
            INSTALL_PACKAGES=false
            ;;
        --no-helpers)
            WRITE_HELPERS=false
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
    shift
done

if [ "$(uname -s)" != "Linux" ]; then
    die "This guest setup script is Linux-only. Do not run it on macOS."
fi

if [ "$CONFIRMED_VM" != true ]; then
    usage >&2
    die "Refusing to run without --inside-unsafe-vm. Use a disposable/template UTM guest, not a trusted host."
fi

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
else
    die "Cannot read /etc/os-release; this script supports Debian/Ubuntu-style guests only."
fi

os_family="${ID:-} ${ID_LIKE:-}"
case " $os_family " in
    *" debian "*|*" ubuntu "*) ;;
    *) die "Unsupported guest OS family: ${PRETTY_NAME:-unknown}. Use Debian/Ubuntu or install tools manually." ;;
esac

SUDO_CMD=()
if [ "$(id -u)" != "0" ]; then
    have sudo || die "sudo is required when not running as root."
    SUDO_CMD=(sudo)
fi

create_workspace() {
    run_cmd mkdir -p "$HOME/Downloads/raw" "$HOME/work/pages" "$HOME/work/sanitized" "$HOME/work/logs" "$HOME/bin"
    if [ "$DRY_RUN" != true ]; then
        chmod 700 "$HOME/Downloads/raw" "$HOME/work" "$HOME/work/pages" "$HOME/work/sanitized" "$HOME/work/logs" "$HOME/bin"
    fi
}

install_packages() {
    [ "$INSTALL_PACKAGES" = true ] || return 0
    have apt-get || die "apt-get is required for automatic Debian/Ubuntu guest setup."

    packages=(clamav clamav-freshclam poppler-utils img2pdf ocrmypdf imagemagick qpdf p7zip-full unzip file libimage-exiftool-perl)
    log "Installing Linux guest triage/sanitization packages: ${packages[*]}"
    run_cmd env DEBIAN_FRONTEND=noninteractive "${SUDO_CMD[@]}" apt-get update
    run_cmd env DEBIAN_FRONTEND=noninteractive "${SUDO_CMD[@]}" apt-get install -y --no-install-recommends "${packages[@]}"

    if have freshclam; then
        if ! run_cmd "${SUDO_CMD[@]}" freshclam; then
            warn "freshclam did not complete. If clamav-freshclam is running, stop the service temporarily or update signatures later."
        fi
    fi
}

write_pdf_helper() {
    [ "$WRITE_HELPERS" = true ] || return 0
    helper="$HOME/bin/unsafe-flatten-pdf"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $helper"
        return 0
    fi
    cat >"$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: unsafe-flatten-pdf input.pdf output.pdf\n' >&2
    exit 2
fi
input="$1"
output="$2"
workdir="$(mktemp -d)"
cleanup() { rm -rf "$workdir"; }
trap cleanup EXIT
mkdir -p "$workdir/pages"
pdftoppm -r 200 -png "$input" "$workdir/pages/page"
find "$workdir/pages" -name 'page-*.png' | sort -V >"$workdir/pages.txt"
if [ ! -s "$workdir/pages.txt" ]; then
    printf 'No pages were rendered from %s\n' "$input" >&2
    exit 1
fi
xargs -a "$workdir/pages.txt" img2pdf -o "$output"
EOF
    chmod 700 "$helper"
}

write_image_helper() {
    [ "$WRITE_HELPERS" = true ] || return 0
    helper="$HOME/bin/unsafe-strip-image"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $helper"
        return 0
    fi
    cat >"$helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: unsafe-strip-image input-image output-image\n' >&2
    exit 2
fi
if command -v magick >/dev/null 2>&1; then
    magick "$1" -strip "$2"
elif command -v convert >/dev/null 2>&1; then
    convert "$1" -strip "$2"
else
    printf 'ImageMagick command not found (expected magick or convert)\n' >&2
    exit 1
fi
EOF
    chmod 700 "$helper"
}

write_guest_notes() {
    notes="$HOME/work/README-unsafe-triage.md"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $notes"
        return 0
    fi
    cat >"$notes" <<'EOF'
# Unsafe VM triage notes

Default folders:
- Raw downloads: `~/Downloads/raw`
- Temporary pages: `~/work/pages`
- Sanitized output: `~/work/sanitized`
- Session logs: `~/work/logs`

Basic workflow:
1. Download raw files only inside the VM.
2. Record source URL and hashes: `cd ~/Downloads/raw && sha256sum *`.
3. Scan: `clamscan -r --infected ~/Downloads/raw`.
4. Flatten PDFs: `unsafe-flatten-pdf ~/Downloads/raw/input.pdf ~/work/sanitized/output.pdf`.
5. Optional OCR: `ocrmypdf --force-ocr ~/work/sanitized/output.pdf ~/work/sanitized/output-ocr.pdf`.
6. Re-encode images: `unsafe-strip-image input.jpg ~/work/sanitized/output.png`.
7. Transfer only sanitized outputs, never raw downloads.

Dangerzone is useful for GUI document conversion, but install it only from the
official project instructions inside the VM and keep treating the VM as untrusted.
EOF
    chmod 600 "$notes"
}

create_workspace
install_packages
write_pdf_helper
write_image_helper
write_guest_notes

cat <<'EOF'

Guest setup complete. Before unsafe browsing, verify UTM isolation on the host:
- Clipboard sharing off.
- Shared folders off, or only Sanitized-Outbox for sanitized transfer.
- USB auto-connect off or prompt-only.
- Network is Shared + Isolate Guest from Host, Emulated VLAN, or Host Only.
- Use Disposable Mode / Run without saving changes when possible.
EOF
