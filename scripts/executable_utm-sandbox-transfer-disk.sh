#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VOLUME="/Volumes/UnsafeLab"
VOLUME="$DEFAULT_VOLUME"
SIZE="2g"
NAME=""
DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: utm-sandbox-transfer-disk.sh [options]

Create a blank sparse raw disk image on the encrypted UnsafeLab volume for the
higher-assurance dirty-VM -> offline-transfer-VM workflow.

Options:
  --volume PATH   Mounted UnsafeLab volume. Default: /Volumes/UnsafeLab.
  --size SIZE     Sparse image size, for example 512m, 2g, or 10g. Default: 2g.
  --name NAME     Output file name. Default: transfer-YYYYMMDD-HHMMSS.raw.
  --dry-run       Print commands that would run.
  -h, --help      Show this help.

Safety:
  This helper creates a new blank file only. It refuses to overwrite existing
  files, does not format or mount the image on the Mac, and does not attach it to
  UTM. Format and mount the disk only inside the disposable/transfer VMs.
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

require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        die "This helper is macOS-only because it prepares a UTM-for-Mac transfer image."
    fi
}

volume_info() {
    diskutil info "$VOLUME" 2>/dev/null || true
}

require_volume_ready() {
    if [ "$DRY_RUN" = true ] && [ ! -d "$VOLUME" ]; then
        log "Would require mounted APFS (Encrypted) volume at $VOLUME."
        return 0
    fi

    [ -d "$VOLUME" ] || die "Volume path does not exist: $VOLUME"
    have diskutil || die "diskutil is required to verify the mounted volume."
    info="$(volume_info)"
    [ -n "$info" ] || die "diskutil could not inspect $VOLUME. Is it mounted?"
    if ! printf '%s\n' "$info" | grep -Eiq 'File System Personality:[[:space:]]*APFS|Type \(Bundle\):[[:space:]]*apfs'; then
        die "$VOLUME does not appear to be APFS. Use the APFS (Encrypted) UnsafeLab volume."
    fi
    if ! printf '%s\n' "$info" | grep -Eiq 'Encrypted:[[:space:]]*Yes'; then
        die "$VOLUME does not appear encrypted. Use the APFS (Encrypted) UnsafeLab volume."
    fi
}

validate_size() {
    case "$SIZE" in
        *[!0-9mMgG]*|""|*[mMgG][mMgG]*)
            die "Invalid --size '$SIZE'. Use values like 512m, 2g, or 10g."
            ;;
        *[mMgG]) ;;
        *) die "Invalid --size '$SIZE'. Include m or g suffix, for example 2g." ;;
    esac
}

validate_name() {
    if [ -z "$NAME" ]; then
        NAME="transfer-$(date +%Y%m%d-%H%M%S).raw"
    fi
    case "$NAME" in
        */*|.*|""|*..*) die "Invalid --name '$NAME'. Use a simple file name such as transfer-case.raw." ;;
    esac
    case "$NAME" in
        *.raw|*.img) ;;
        *) die "Invalid --name '$NAME'. Use .raw or .img extension." ;;
    esac
}

create_transfer_disk() {
    require_volume_ready
    validate_size
    validate_name

    out_dir="$VOLUME/Client-App-Tests/Transfer-Disks"
    out_path="$out_dir/$NAME"
    if [ -e "$out_path" ]; then
        die "Refusing to overwrite existing file: $out_path"
    fi
    have mkfile || die "mkfile is required on macOS to create the sparse raw image."

    run_cmd mkdir -p "$out_dir"
    run_cmd chmod 700 "$out_dir"
    run_cmd mkfile -n "$SIZE" "$out_path"
    run_cmd chmod 600 "$out_path"

    if [ "$DRY_RUN" = true ]; then
        log "Dry-run complete; no changes made. Would create blank sparse transfer disk image: $out_path"
    else
        log "Created blank sparse transfer disk image: $out_path"
    fi
    cat <<EOF

Higher-assurance transfer workflow:
1. Keep dirty VM and transfer VM shut down before changing attached drives.
2. In UTM, attach this existing raw image to the dirty VM.
3. Boot the dirty VM and format/mount the new guest disk inside the VM only.
   Example inside Linux guest, after confirming the device name carefully:
     sudo mkfs.ext4 /dev/vdb
     sudo mkdir -p /mnt/transfer && sudo mount /dev/vdb /mnt/transfer
4. Copy candidate files from the dirty VM to the transfer disk, then shut down.
5. Detach the image from the dirty VM and attach it to the no-internet transfer VM.
6. Mount it read-only when practical, sanitize documents there, and copy only
   sanitized outputs to /Volumes/UnsafeLab/Sanitized-Outbox.
7. Do not mount this disk image on the Mac host and do not use it as a shared folder.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --volume)
            [ "$#" -ge 2 ] || die "--volume requires a path."
            VOLUME="${2%/}"
            shift
            ;;
        --size)
            [ "$#" -ge 2 ] || die "--size requires a value."
            SIZE="$2"
            shift
            ;;
        --name)
            [ "$#" -ge 2 ] || die "--name requires a file name."
            NAME="$2"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

require_macos
create_transfer_disk
