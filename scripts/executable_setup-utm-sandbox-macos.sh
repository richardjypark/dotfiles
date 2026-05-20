#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VOLUME="/Volumes/UnsafeLab"
APP_STORE_ID="1538878817"
APP_STORE_DEEP_LINK="macappstore://itunes.apple.com/app/id${APP_STORE_ID}"
APP_STORE_WEB_URL="https://apps.apple.com/app/utm-virtual-machines/id${APP_STORE_ID}"

VOLUME="$DEFAULT_VOLUME"
INSTALL=false
INSTALL_METHOD="app-store"
PREPARE=true
VERIFY=false
DRY_RUN=false
WRITE_VOLUME_README=true

usage() {
    cat <<'EOF'
Usage: setup-utm-sandbox-macos.sh [options]

Prepare a secure-by-default UTM unsafe-work workspace on macOS.

Recommended first run, after manually formatting and mounting an encrypted SSD:
  setup-utm-sandbox-macos.sh --install --volume /Volumes/UnsafeLab

Homebrew/free-build install path:
  setup-utm-sandbox-macos.sh --install --install-method brew --volume /Volumes/UnsafeLab

Audit without changing anything:
  setup-utm-sandbox-macos.sh --verify --volume /Volumes/UnsafeLab

Options:
  --install                 Install or open UTM using --install-method.
  --install-method METHOD   app-store (default), brew, or none.
  --volume PATH             Mounted unsafe lab volume. Default: /Volumes/UnsafeLab.
  --prepare                 Prepare the mounted volume. This is the default action.
  --no-prepare              Skip folder/exclusion setup.
  --verify                  Verify UTM presence and UnsafeLab host settings only.
  --dry-run                 Print commands that would run.
  --no-readme               Do not write UnsafeLab-README.txt on the volume.
  -h, --help                Show this help.

Safety:
  This helper does not format, partition, erase, or rename disks. Use Disk Utility
  manually first: GUID Partition Map + APFS (Encrypted), named UnsafeLab.
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        printf 'Would run:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        die "This helper is macOS-only."
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

open_utm_app_store_page() {
    log "Opening the UTM Mac App Store page. Complete installation there for automatic updates."
    if ! run_cmd open "$APP_STORE_DEEP_LINK"; then
        warn "Could not open the App Store deep link; opening the web listing instead."
        run_cmd open "$APP_STORE_WEB_URL"
    fi
}

install_utm_app_store() {
    if utm_installed; then
        log "UTM already appears to be installed."
        return 0
    fi

    if have mas && mas account >/dev/null 2>&1; then
        log "Installing UTM from the Mac App Store with mas app id ${APP_STORE_ID}."
        if ! run_cmd mas install "$APP_STORE_ID"; then
            warn "mas install failed; opening the App Store page instead."
            open_utm_app_store_page
        fi
    else
        open_utm_app_store_page
    fi
}

install_utm_brew() {
    have brew || die "Homebrew is required for --install-method brew. Install Homebrew first or use app-store."
    if brew list --cask utm >/dev/null 2>&1; then
        log "UTM Homebrew cask is already installed."
    else
        log "Installing UTM with Homebrew cask."
        run_cmd brew install --cask utm
    fi
}

install_utm() {
    case "$INSTALL_METHOD" in
        app-store)
            install_utm_app_store
            ;;
        brew)
            install_utm_brew
            ;;
        none)
            log "Skipping UTM install because --install-method none was selected."
            ;;
        *)
            die "Unknown --install-method: $INSTALL_METHOD"
            ;;
    esac
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
    [ -n "$info" ] || die "diskutil could not inspect $VOLUME. Is it a mounted local volume?"

    if ! printf '%s\n' "$info" | grep -Eiq 'File System Personality:[[:space:]]*APFS|Type \(Bundle\):[[:space:]]*apfs'; then
        die "$VOLUME does not appear to be APFS. Reformat manually in Disk Utility as APFS (Encrypted) with GUID Partition Map."
    fi
    if ! printf '%s\n' "$info" | grep -Eiq 'Encrypted:[[:space:]]*Yes'; then
        die "$VOLUME does not appear to be encrypted. Reformat manually in Disk Utility as APFS (Encrypted)."
    fi
}

prepare_folders() {
    folders="VMs Raw-Quarantine Sanitized-Outbox Client-App-Tests Client-App-Tests/Transfer-Disks Logs"
    for folder in $folders; do
        run_cmd mkdir -p "$VOLUME/$folder"
        run_cmd chmod 700 "$VOLUME/$folder"
    done
}

exclude_time_machine() {
    if ! have tmutil; then
        warn "tmutil not found; add $VOLUME to Time Machine exclusions manually."
        return 0
    fi
    log "Adding Time Machine exclusion for $VOLUME."
    if ! run_cmd tmutil addexclusion -p "$VOLUME"; then
        warn "tmutil addexclusion failed; add the volume in System Settings -> General -> Time Machine -> Options."
    fi
}

exclude_spotlight() {
    log "Adding Spotlight privacy markers for $VOLUME."
    run_cmd touch "$VOLUME/.metadata_never_index"
    if have mdutil; then
        if [ "$DRY_RUN" = true ]; then
            run_cmd mdutil -i off "$VOLUME"
        elif ! mdutil -i off "$VOLUME" >/dev/null; then
            warn "mdutil could not disable indexing; add the volume in System Settings -> Spotlight -> Search Privacy."
        fi
    else
        warn "mdutil not found; add the volume in Spotlight Search Privacy manually."
    fi
}

write_volume_readme() {
    [ "$WRITE_VOLUME_README" = true ] || return 0
    readme_path="$VOLUME/UnsafeLab-README.txt"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $readme_path"
        return 0
    fi
    cat >"$readme_path" <<EOF
UnsafeLab checklist
===================

This volume is for unsafe UTM work only.

Rules:
- Store UTM VM bundles under: $VOLUME/VMs
- Keep raw host-visible files under: $VOLUME/Raw-Quarantine
- Transfer only sanitized files through: $VOLUME/Sanitized-Outbox
- Keep session notes, source URL records, and SHA-256 hash logs under: $VOLUME/Logs
- Keep higher-assurance intermediate transfer disk images under: $VOLUME/Client-App-Tests/Transfer-Disks
- Do not share personal Mac folders, iCloud Drive, password-manager data, or backup disks with dirty VMs.
- In UTM dirty VMs: clipboard off, shared folders off by default, USB auto-connect off/prompt-only, no Bridged networking unless a client test truly requires it.
- Prefer Shared Network with Isolate Guest from Host, Emulated VLAN, or Host Only.
- Start risky browsing VMs with Disposable Mode / Run without saving changes when possible.
- Eject this volume when unsafe work is finished.

Review the full guide in the dotfiles repo:
  docs/utm-sandbox-macos.md
EOF
}

write_log_template() {
    [ "$WRITE_VOLUME_README" = true ] || return 0
    template_path="$VOLUME/Logs/session-template.md"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $template_path"
        return 0
    fi
    cat >"$template_path" <<'EOF'
# UnsafeLab session log

- Date/time:
- VM name:
- UTM mode: Disposable / snapshot / persistent
- Network mode:
- Source URL:
- Downloaded file names:
- SHA-256 hashes:
- Scanner results:
- Sanitizer used:
- Output copied to Sanitized-Outbox:
- Follow-up / deletion notes:

Do not paste secrets or confidential document contents here. Keep this log on the
encrypted UnsafeLab volume.
EOF
}

write_vm_isolation_checklist() {
    [ "$WRITE_VOLUME_README" = true ] || return 0
    checklist_path="$VOLUME/VM-Isolation-Checklist.md"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $checklist_path"
        return 0
    fi
    cat >"$checklist_path" <<EOF
# UTM VM isolation checklist

Copy this checklist for each dirty or client-test VM stored under ${VOLUME}/VMs.

- [ ] VM name:
- [ ] VM bundle is stored under ${VOLUME}/VMs/.
- [ ] Architecture matches host where practical: ARM64 on Apple Silicon, x86_64 on Intel.
- [ ] QEMU backend selected when Disposable Mode / Run without saving changes is required.
- [ ] Network is Shared Network with Isolate Guest from Host, Emulated VLAN, or Host Only.
- [ ] Bridged networking is off unless a specific client test requires LAN presence.
- [ ] Port forwarding is not configured.
- [ ] Clipboard sharing is off.
- [ ] Shared directory is off, or temporarily limited to ${VOLUME}/Sanitized-Outbox for sanitized files only.
- [ ] USB auto-connect is off or prompt-only; no personal USB devices are forwarded.
- [ ] Automatic VM screenshots are disabled if malicious or sensitive content may display.
- [ ] No iCloud, browser sync, password-manager sync, or personal credentials are configured in the guest.
- [ ] Browser downloads ask every time and default to a VM-internal raw folder.
- [ ] Raw files are hashed/scanned inside the VM and sanitized before any host-visible transfer.
- [ ] Risky session is discarded, reverted to a clean snapshot, or the throwaway VM is deleted afterward.
EOF
    chmod 600 "$checklist_path"
}

prepare_volume() {
    require_volume_ready
    prepare_folders
    exclude_time_machine
    exclude_spotlight
    write_volume_readme
    write_log_template
    write_vm_isolation_checklist
    if [ "$DRY_RUN" = true ]; then
        log "Dry-run complete; no changes made. Would prepare $VOLUME for UTM unsafe-work storage."
    else
        log "Prepared $VOLUME for UTM unsafe-work storage."
    fi
    log "Next: create or move UTM VM bundles into $VOLUME/VMs and configure VM isolation in UTM."
}

check_path() {
    label="$1"
    path="$2"
    if [ -e "$path" ]; then
        log "OK: $label exists ($path)"
        return 0
    fi
    warn "$label is missing ($path)"
    return 1
}

check_private_dir() {
    label="$1"
    path="$2"
    check_path "$label" "$path" || return 1
    mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
    if [ "$mode" = "700" ]; then
        log "OK: $label has owner-only permissions (700)."
        return 0
    fi
    warn "$label permissions are ${mode:-unknown}; expected 700 so other local users cannot browse lab files."
    return 1
}

verify_time_machine() {
    if ! have tmutil; then
        warn "tmutil not found; cannot verify Time Machine exclusion."
        return 1
    fi
    out="$(tmutil isexcluded "$VOLUME" 2>/dev/null || true)"
    if printf '%s\n' "$out" | grep -Eiq '\[Excluded\]|is excluded'; then
        log "OK: Time Machine reports $VOLUME is excluded."
        return 0
    fi
    warn "Time Machine exclusion not confirmed for $VOLUME."
    return 1
}

verify_spotlight() {
    if [ -e "$VOLUME/.metadata_never_index" ]; then
        log "OK: Spotlight marker exists at $VOLUME/.metadata_never_index."
        return 0
    fi
    if have mdutil; then
        out="$(mdutil -s "$VOLUME" 2>/dev/null || true)"
        if printf '%s\n' "$out" | grep -Eiq 'Indexing disabled|disabled'; then
            log "OK: Spotlight indexing appears disabled for $VOLUME."
            return 0
        fi
    fi
    warn "Spotlight exclusion not confirmed for $VOLUME."
    return 1
}

verify_setup() {
    failures=0

    if utm_installed; then
        log "OK: UTM appears to be installed."
    else
        warn "UTM was not found in Applications or Spotlight metadata."
        failures=$((failures + 1))
    fi

    if require_volume_ready; then
        log "OK: $VOLUME appears to be APFS (Encrypted). Confirm GUID Partition Map in Disk Utility."
    else
        failures=$((failures + 1))
    fi

    for folder in VMs Raw-Quarantine Sanitized-Outbox Client-App-Tests Client-App-Tests/Transfer-Disks Logs; do
        if ! check_private_dir "UnsafeLab/$folder" "$VOLUME/$folder"; then
            failures=$((failures + 1))
        fi
    done

    if ! verify_time_machine; then
        failures=$((failures + 1))
    fi
    if ! verify_spotlight; then
        failures=$((failures + 1))
    fi

    cat <<'EOF'

Manual UTM VM settings to verify:
- Dirty VM stored under UnsafeLab/VMs.
- QEMU backend for Disposable Mode / Run without saving changes.
- Network is Shared Network + Isolate Guest from Host, Emulated VLAN, or Host Only.
- No Bridged networking unless a required client test explicitly needs it.
- Clipboard sharing off.
- Shared directory off, or only Sanitized-Outbox for sanitized transfers.
- USB auto-connect off or prompt-only.
- No iCloud, browser sync, password-manager sync, or personal credentials in dirty VMs.
EOF

    if [ "$failures" -gt 0 ]; then
        die "Verification found $failures issue(s)."
    fi
    log "Verification passed."
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install)
            INSTALL=true
            ;;
        --install-method)
            [ "$#" -ge 2 ] || die "--install-method requires app-store, brew, or none."
            INSTALL_METHOD="$2"
            shift
            ;;
        --volume)
            [ "$#" -ge 2 ] || die "--volume requires a path."
            VOLUME="${2%/}"
            shift
            ;;
        --prepare)
            PREPARE=true
            ;;
        --no-prepare)
            PREPARE=false
            ;;
        --verify)
            VERIFY=true
            PREPARE=false
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --no-readme)
            WRITE_VOLUME_README=false
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

if [ "$INSTALL" = true ]; then
    install_utm
fi
if [ "$PREPARE" = true ]; then
    prepare_volume
fi
if [ "$VERIFY" = true ]; then
    verify_setup
fi

if [ "$INSTALL" != true ] && [ "$PREPARE" != true ] && [ "$VERIFY" != true ]; then
    usage
fi
