#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VOLUME="/Volumes/UnsafeLab"
VOLUME="$DEFAULT_VOLUME"
DAYS=30
MAX_FILES=25

usage() {
    cat <<'EOF'
Usage: utm-sandbox-inventory.sh [options]

Read-only inventory for the encrypted UnsafeLab volume. Reports directory sizes,
stale quarantine files, stale transfer disk images, and sanitized outbox contents
so you can clean up unsafe material deliberately.

Options:
  --volume PATH    Mounted UnsafeLab volume. Default: /Volumes/UnsafeLab.
  --days N         Age threshold for stale-file reporting. Default: 30.
  --max-files N    Maximum entries per report section. Default: 25.
  -h, --help       Show this help.

Safety:
  This helper is read-only. It does not delete, open, preview, mount, quarantine,
  or upload files. Review paths and remove stale unsafe files manually when you
  are sure they are no longer needed.
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        die "This helper is macOS-only because it inventories the UTM UnsafeLab volume."
    fi
}

validate_number() {
    label="$1"
    value="$2"
    case "$value" in
        ""|*[!0-9]*) die "$label must be a non-negative integer." ;;
    esac
}

require_volume() {
    [ -d "$VOLUME" ] || die "Volume path does not exist: $VOLUME"
    if [ -d "$VOLUME/Backups.backupdb" ] || [ -d "$VOLUME/.backupdb" ]; then
        warn "$VOLUME appears to contain Time Machine backup data; inventory is read-only, but use a dedicated UnsafeLab SSD for unsafe work."
    fi
}

warn_if_volume_not_encrypted_apfs() {
    if ! have diskutil; then
        warn "diskutil not found; cannot confirm APFS encryption for $VOLUME."
        return 0
    fi
    info="$(diskutil info "$VOLUME" 2>/dev/null || true)"
    if ! printf '%s\n' "$info" | grep -Eiq 'File System Personality:[[:space:]]*APFS|Type \(Bundle\):[[:space:]]*apfs'; then
        warn "$VOLUME does not appear to be APFS; confirm you are inventorying the encrypted UnsafeLab volume."
    fi
    if ! printf '%s\n' "$info" | grep -Eiq 'Encrypted:[[:space:]]*Yes'; then
        warn "$VOLUME does not appear encrypted; confirm you are inventorying the encrypted UnsafeLab volume."
    fi
}

print_size() {
    path="$1"
    if [ -e "$path" ]; then
        du -sh "$path" 2>/dev/null || true
    else
        printf 'missing\t%s\n' "$path"
    fi
}

list_stale_files() {
    title="$1"
    dir="$2"
    pattern="$3"
    log ""
    log "$title"
    if [ ! -d "$dir" ]; then
        warn "Missing directory: $dir"
        return 0
    fi
    find "$dir" -type f -name "$pattern" ! -name 'README*' -mtime +"$DAYS" -print 2>/dev/null \
        | sort \
        | head -n "$MAX_FILES" \
        | while IFS= read -r path; do
            [ -n "$path" ] || continue
            print_size "$path"
        done
}

list_recent_files() {
    title="$1"
    dir="$2"
    log ""
    log "$title"
    if [ ! -d "$dir" ]; then
        warn "Missing directory: $dir"
        return 0
    fi
    find "$dir" -type f -print 2>/dev/null \
        | sort \
        | head -n "$MAX_FILES" \
        | while IFS= read -r path; do
            [ -n "$path" ] || continue
            print_size "$path"
        done
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --volume)
            [ "$#" -ge 2 ] || die "--volume requires a path."
            VOLUME="${2%/}"
            shift
            ;;
        --days)
            [ "$#" -ge 2 ] || die "--days requires a number."
            DAYS="$2"
            shift
            ;;
        --max-files)
            [ "$#" -ge 2 ] || die "--max-files requires a number."
            MAX_FILES="$2"
            shift
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
validate_number "--days" "$DAYS"
validate_number "--max-files" "$MAX_FILES"
require_volume
warn_if_volume_not_encrypted_apfs
have du || die "du is required."
have find || die "find is required."

log "UnsafeLab inventory (read-only)"
log "Volume: $VOLUME"
log "Stale threshold: older than $DAYS day(s)"
log ""
log "Top-level sizes"
for dir in VMs Raw-Quarantine Sanitized-Outbox Client-App-Tests Client-App-Tests/Transfer-Disks Logs; do
    print_size "$VOLUME/$dir"
done

list_stale_files "Stale raw quarantine files" "$VOLUME/Raw-Quarantine" '*'
list_stale_files "Stale transfer raw disk images" "$VOLUME/Client-App-Tests/Transfer-Disks" '*.raw'
list_stale_files "Stale transfer image files" "$VOLUME/Client-App-Tests/Transfer-Disks" '*.img'
list_stale_files "Stale transfer qcow2 images" "$VOLUME/Client-App-Tests/Transfer-Disks" '*.qcow2'
list_recent_files "Sanitized outbox sample (review before copying to normal storage)" "$VOLUME/Sanitized-Outbox"

cat <<'EOF'

Cleanup guidance:
- Do not open raw quarantine files on the host to decide whether to keep them.
- Prefer deleting stale raw files, old transfer disk images, and throwaway client
  test artifacts after the matter is closed.
- Keep only sanitized outputs that are still needed, then eject UnsafeLab.
EOF
