#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VOLUME="/Volumes/UnsafeLab"
VOLUME="$DEFAULT_VOLUME"
VMS_DIR=""
MAX_DEPTH=3
FAIL_ON_WARNING=false

usage() {
    cat <<'EOF'
Usage: utm-sandbox-audit.sh [options]

Best-effort, read-only audit for the macOS UTM UnsafeLab workflow.

Options:
  --volume PATH        Mounted UnsafeLab volume. Default: /Volumes/UnsafeLab.
  --vms-dir PATH       Directory containing .utm bundles. Default: <volume>/VMs.
  --max-depth N        Search depth for nested .utm bundles under --vms-dir. Default: 3.
  --fail-on-warning    Exit non-zero when risky settings or missing controls are found.
  -h, --help           Show this help.

Safety:
  This helper is read-only. It does not modify UTM bundles, host settings, disks,
  quarantine attributes, or VM configuration. Use it as a prompt for manual UTM
  GUI review, not as proof that a VM is safe.
EOF
}

log() { printf '%s\n' "$*"; }
ok() { printf 'OK: %s\n' "$*"; }
info() { printf 'INFO: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

WARNINGS=0

require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        die "This helper is macOS-only because it audits UTM for Mac workflows."
    fi
}

utm_installed() {
    if [ -d "/Applications/UTM.app" ]; then
        return 0
    fi
    if have mdfind && mdfind 'kMDItemCFBundleIdentifier == "com.utmapp.UTM"' 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

volume_info() {
    diskutil info "$VOLUME" 2>/dev/null || true
}

audit_volume() {
    if [ ! -d "$VOLUME" ]; then
        warn "UnsafeLab volume is not mounted: $VOLUME"
        return 0
    fi

    if have diskutil; then
        info_text="$(volume_info)"
        if printf '%s\n' "$info_text" | grep -Eiq 'File System Personality:[[:space:]]*APFS|Type \(Bundle\):[[:space:]]*apfs'; then
            ok "$VOLUME appears to be APFS. Confirm GUID Partition Map in Disk Utility."
        else
            warn "$VOLUME does not appear to be APFS. Expected APFS (Encrypted)."
        fi
        if printf '%s\n' "$info_text" | grep -Eiq 'Encrypted:[[:space:]]*Yes'; then
            ok "$VOLUME appears encrypted."
        else
            warn "$VOLUME does not appear encrypted. Expected APFS (Encrypted)."
        fi
    else
        warn "diskutil not found; cannot verify APFS encryption."
    fi

    if [ -d "$VOLUME/Backups.backupdb" ] || [ -d "$VOLUME/.backupdb" ]; then
        warn "$VOLUME appears to contain Time Machine backup data; use a dedicated UnsafeLab SSD, not a backup disk."
    fi

    for folder in VMs Raw-Quarantine Sanitized-Outbox Client-App-Tests Client-App-Tests/Transfer-Disks Logs; do
        path="$VOLUME/$folder"
        if [ -d "$path" ]; then
            ok "folder exists: $path"
            mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
            if [ "$mode" = "700" ]; then
                ok "folder has owner-only permissions (700): $path"
            else
                warn "folder permissions are ${mode:-unknown}; expected 700: $path"
            fi
        else
            warn "missing UnsafeLab folder: $path"
        fi
    done

    for file in \
        UnsafeLab-README.txt \
        VM-Isolation-Checklist.md \
        Logs/session-template.md \
        Raw-Quarantine/README-DO-NOT-OPEN.txt \
        Sanitized-Outbox/README.txt \
        Client-App-Tests/README.txt \
        Client-App-Tests/Transfer-Disks/README-DO-NOT-MOUNT-ON-HOST.txt; do
        path="$VOLUME/$file"
        if [ -f "$path" ]; then
            ok "guidance file exists: $path"
            mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
            if [ "$mode" = "600" ]; then
                ok "guidance file has owner-only permissions (600): $path"
            else
                warn "guidance file permissions are ${mode:-unknown}; expected 600: $path"
            fi
        else
            warn "missing UnsafeLab guidance file: $path"
        fi
    done
}

audit_time_machine() {
    if ! have tmutil; then
        warn "tmutil not found; verify Time Machine exclusion manually."
        return 0
    fi
    out="$(tmutil isexcluded "$VOLUME" 2>/dev/null || true)"
    raw_out="$(tmutil isexcluded "$VOLUME/Raw-Quarantine" 2>/dev/null || true)"
    if printf '%s\n' "$out" | grep -Eiq '\[Excluded\]|is excluded' \
        && printf '%s\n' "$raw_out" | grep -Eiq '\[Excluded\]|is excluded'; then
        ok "Time Machine reports $VOLUME and Raw-Quarantine are excluded."
    else
        warn "Time Machine exclusion not confirmed for both $VOLUME and Raw-Quarantine."
    fi
}

audit_spotlight() {
    if [ -e "$VOLUME/.metadata_never_index" ] && [ -e "$VOLUME/Raw-Quarantine/.metadata_never_index" ]; then
        ok "Spotlight markers exist on the volume and Raw-Quarantine."
        return 0
    fi
    if have mdutil; then
        out="$(mdutil -s "$VOLUME" 2>/dev/null || true)"
        if printf '%s\n' "$out" | grep -Eiq 'Indexing disabled|disabled'; then
            ok "Spotlight indexing appears disabled for $VOLUME."
        else
            warn "Spotlight exclusion not confirmed for $VOLUME."
        fi
    else
        warn "mdutil not found; verify Spotlight Search Privacy manually."
    fi
}

audit_utm_presence() {
    if utm_installed; then
        ok "UTM appears to be installed."
    else
        warn "UTM was not found in /Applications or Spotlight metadata."
    fi
}

audit_one_bundle() {
    bundle="$1"
    config="$bundle/config.plist"
    if [ ! -f "$config" ]; then
        warn "missing config.plist in UTM bundle: $bundle"
        return 0
    fi

    info "Scanning UTM bundle: $bundle"
    if ! python3 - "$config" "$bundle" <<'PY'
from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path

config = Path(sys.argv[1])
bundle = Path(sys.argv[2])
findings: list[tuple[str, str, str, str]] = []

HOST_PATH_RE = re.compile(
    r"/Users/[^'\"<>]*/(Desktop|Documents|Downloads|Library/Mobile Documents|\.ssh)(?:/|$)|"
    r"/Volumes/(?!UnsafeLab(?:/|$))[^'\"<>]*(?:Time Machine|Backup|Mobile Documents|$)|"
    r"\b(1Password|password[- ]?manager)\b",
    re.IGNORECASE,
)


def short(value: object) -> str:
    text = repr(value)
    if len(text) > 160:
        text = text[:157] + "..."
    return text


def truthy(value: object) -> bool:
    if value is True:
        return True
    if value is False or value is None:
        return False
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in {"", "0", "false", "no", "disabled", "off", "none", "null"}:
            return False
        return True
    if isinstance(value, (dict, list, tuple, set)):
        return bool(value)
    return False


def add(kind: str, path: str, value: object, reason: str) -> None:
    findings.append((kind, path, short(value), reason))


def walk(obj: object, path: str = "$") -> None:
    if isinstance(obj, dict):
        for key, value in obj.items():
            key_text = str(key)
            key_lower = key_text.lower()
            child_path = f"{path}.{key_text}"
            if "clipboard" in key_lower and truthy(value):
                add("clipboard", child_path, value, "clipboard sharing may be enabled; disable clipboard sharing in UTM")
            if ("share" in key_lower or "virtfs" in key_lower or "webdav" in key_lower) and truthy(value):
                add("sharing", child_path, value, "shared-folder bridge may be enabled; turn it off or limit it to Sanitized-Outbox only during transfer")
            if "usb" in key_lower and truthy(value):
                add("usb", child_path, value, "USB forwarding or auto-connect may be enabled; disable auto-connect or use prompt-only")
            if "port" in key_lower and "forward" in key_lower and truthy(value):
                add("port-forward", child_path, value, "guest port forwarding may expose services; remove port forwards unless required")
            walk(value, child_path)
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            walk(value, f"{path}[{index}]")
    elif isinstance(obj, str):
        lower = obj.lower()
        if "bridged" in lower or lower == "bridge" or "bridge interface" in lower:
            add("network", path, obj, "bridged networking can expose the guest to the LAN; prefer Shared Network with host isolation, Emulated VLAN, or Host Only")
        if "clipboard" in lower and any(token in lower for token in ("true", "enable", "shared")):
            add("clipboard", path, obj, "clipboard sharing may be enabled; disable clipboard sharing in UTM")
        if "port forward" in lower or "port-forward" in lower or "portforward" in lower:
            add("port-forward", path, obj, "guest port forwarding may expose services; remove port forwards unless required")
        if HOST_PATH_RE.search(obj):
            add("host-path", path, obj, "possible host personal folder or non-UnsafeLab volume reference; remove Mac personal folder shares")

try:
    with config.open("rb") as fh:
        data = plistlib.load(fh)
except Exception as exc:  # noqa: BLE001 - user-facing audit should report parse failures
    print(f"WARN: {bundle}: could not parse config.plist: {exc}")
    sys.exit(1)

walk(data)

if findings:
    for kind, path, value, reason in findings:
        print(f"WARN: {bundle}: {kind}: {reason}; plist path {path}; value {value}")
    sys.exit(1)

print(f"OK: {bundle}: no obvious bridged networking, clipboard, shared-folder, USB, port-forward, or personal host-path indicators found in config.plist")
sys.exit(0)
PY
    then
        WARNINGS=$((WARNINGS + 1))
    fi
}

audit_bundles() {
    if [ -z "$VMS_DIR" ]; then
        VMS_DIR="$VOLUME/VMs"
    fi
    if [ ! -d "$VMS_DIR" ]; then
        warn "VM bundle directory is missing: $VMS_DIR"
        return 0
    fi

    tmp_list="$(mktemp "${TMPDIR:-/tmp}/utm-bundles.XXXXXX")"
    trap 'rm -f "$tmp_list"' EXIT
    find "$VMS_DIR" -maxdepth "$MAX_DEPTH" -type d -name '*.utm' -print0 >"$tmp_list"
    if [ ! -s "$tmp_list" ]; then
        warn "No .utm bundles found in $VMS_DIR. Create/move VMs there before relying on this audit."
        return 0
    fi

    while IFS= read -r -d '' bundle; do
        audit_one_bundle "$bundle"
    done <"$tmp_list"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --volume)
            [ "$#" -ge 2 ] || die "--volume requires a path."
            VOLUME="${2%/}"
            shift
            ;;
        --vms-dir)
            [ "$#" -ge 2 ] || die "--vms-dir requires a path."
            VMS_DIR="${2%/}"
            shift
            ;;
        --max-depth)
            [ "$#" -ge 2 ] || die "--max-depth requires a number."
            MAX_DEPTH="$2"
            case "$MAX_DEPTH" in
                ""|*[!0-9]*) die "--max-depth must be a non-negative integer." ;;
            esac
            shift
            ;;
        --fail-on-warning)
            FAIL_ON_WARNING=true
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

log "UTM UnsafeLab audit (read-only, best effort)"
log "Volume: $VOLUME"
log ""
audit_utm_presence
audit_volume
audit_time_machine
audit_spotlight
audit_bundles

cat <<'EOF'

Manual review still required in UTM:
- Network: Shared Network + Isolate Guest from Host, Emulated VLAN, or Host Only.
- Avoid Bridged networking unless a specific client test requires LAN presence.
- Clipboard sharing off.
- Shared directories off, or limited to Sanitized-Outbox for sanitized transfer.
- USB auto-connect off or prompt-only.
- No iCloud, browser sync, password-manager sync, or personal credentials in dirty VMs.
EOF

if [ "$WARNINGS" -gt 0 ]; then
    warn "$WARNINGS audit warning(s) found."
    if [ "$FAIL_ON_WARNING" = true ]; then
        exit 2
    fi
else
    ok "No audit warnings found. This is not a guarantee of VM containment."
fi
