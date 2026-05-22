#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VOLUME="/Volumes/UnsafeLab"
DEFAULT_UTM_INSTALL_DIR="/Applications"
UTM_BUNDLE_ID="com.utmapp.UTM"
UTM_OFFICIAL_DOWNLOAD_URL="https://mac.getutm.app/"
UTM_GITHUB_RELEASES_URL="https://github.com/utmapp/UTM/releases/latest"
UTM_GITHUB_DMG_URL="https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg"

VOLUME="$DEFAULT_VOLUME"
INSTALL=false
INSTALL_METHOD="github"
INSTALL_DIR="${UTM_INSTALL_DIR:-}"
PREPARE=true
VERIFY=false
DRY_RUN=false
WRITE_GUIDANCE_FILES=true
CLEANUP_UTM_TMPDIR=""
CLEANUP_UTM_MOUNT_DIR=""

usage() {
    cat <<'EOF'
Usage: setup-utm-sandbox-macos.sh [options]

Prepare a secure-by-default UTM unsafe-work workspace on macOS.

Recommended first run, after manually formatting and mounting an encrypted SSD:
  setup-utm-sandbox-macos.sh --install --volume /Volumes/UnsafeLab

Install UTM only, before the UnsafeLab volume is available:
  setup-utm-sandbox-macos.sh --install --no-prepare

Open the official UTM download page without downloading the DMG:
  setup-utm-sandbox-macos.sh --install --install-method web --volume /Volumes/UnsafeLab

Homebrew/free-build install path:
  setup-utm-sandbox-macos.sh --install --install-method brew --volume /Volumes/UnsafeLab

Audit without changing anything:
  setup-utm-sandbox-macos.sh --verify --volume /Volumes/UnsafeLab

Options:
  --install                 Install or open UTM using --install-method.
  --install-method METHOD   github (default), web, brew, or none.
  --install-dir PATH        Directory for GitHub DMG installs. Default: /Applications when writable, otherwise ~/Applications.
  --volume PATH             Mounted unsafe lab volume. Default: /Volumes/UnsafeLab.
  --prepare                 Prepare the mounted volume. This is the default action.
  --no-prepare              Skip folder/exclusion setup.
  --verify                  Verify UTM presence and UnsafeLab host settings only.
  --dry-run                 Print commands that would run.
  --no-guidance-files       Do not write README, marker, checklist, or log template files.
  --no-readme               Deprecated alias for --no-guidance-files.
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

cleanup_utm_download() {
    if [ -n "${CLEANUP_UTM_MOUNT_DIR:-}" ] && [ -d "$CLEANUP_UTM_MOUNT_DIR" ] && have hdiutil; then
        hdiutil detach "$CLEANUP_UTM_MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach -force "$CLEANUP_UTM_MOUNT_DIR" >/dev/null 2>&1 || true
    fi
    if [ -n "${CLEANUP_UTM_TMPDIR:-}" ] && [ -d "$CLEANUP_UTM_TMPDIR" ]; then
        rm -rf "$CLEANUP_UTM_TMPDIR"
    fi
}
trap cleanup_utm_download EXIT

require_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        die "This helper is macOS-only."
    fi
}

find_existing_utm_app() {
    for app_path in "/Applications/UTM.app" "$HOME/Applications/UTM.app"; do
        if [ -d "$app_path" ]; then
            printf '%s\n' "$app_path"
            return 0
        fi
    done

    if have mdfind; then
        found_path="$(mdfind 'kMDItemCFBundleIdentifier == "com.utmapp.UTM"' 2>/dev/null | head -n 1 || true)"
        if [ -n "$found_path" ] && [ -d "$found_path" ]; then
            printf '%s\n' "$found_path"
            return 0
        fi
    fi

    return 1
}

utm_installed() {
    find_existing_utm_app >/dev/null
}

open_utm_official_download_page() {
    log "Opening the free official UTM download page. Choose the GitHub download from that page."
    if ! run_cmd open "$UTM_OFFICIAL_DOWNLOAD_URL"; then
        warn "Could not open the official UTM website; opening GitHub releases instead."
        open_utm_github_releases_page
    fi
}

open_utm_github_releases_page() {
    log "Opening the free UTM GitHub releases page. Download the latest UTM.dmg release asset."
    run_cmd open "$UTM_GITHUB_RELEASES_URL"
}

resolve_utm_install_dir() {
    if [ -n "$INSTALL_DIR" ]; then
        install_dir="${INSTALL_DIR%/}"
        [ -n "$install_dir" ] || install_dir="/"
        printf '%s\n' "$install_dir"
        return 0
    fi

    if [ "$DRY_RUN" = true ] || [ -w "$DEFAULT_UTM_INSTALL_DIR" ]; then
        printf '%s\n' "$DEFAULT_UTM_INSTALL_DIR"
    else
        printf '%s\n' "$HOME/Applications"
    fi
}

utm_install_target_app() {
    install_dir="$(resolve_utm_install_dir)"
    if [ "$install_dir" = "/" ]; then
        printf '/UTM.app\n'
    else
        printf '%s/UTM.app\n' "$install_dir"
    fi
}

verify_utm_app_bundle() {
    app_path="$1"
    [ -d "$app_path" ] || die "UTM.app was not found at $app_path."

    info_plist="$app_path/Contents/Info.plist"
    [ -f "$info_plist" ] || die "UTM.app is missing Contents/Info.plist at $app_path."

    if [ -x /usr/libexec/PlistBuddy ]; then
        bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist" 2>/dev/null || true)"
        [ "$bundle_id" = "$UTM_BUNDLE_ID" ] || die "Unexpected app bundle id ${bundle_id:-missing}; expected $UTM_BUNDLE_ID."
    else
        warn "PlistBuddy not found; skipping bundle identifier verification."
    fi

    if have codesign; then
        codesign --verify --deep --strict "$app_path" >/dev/null 2>&1 || die "codesign verification failed for $app_path."
    else
        warn "codesign not found; skipping code signature verification."
    fi

    if have spctl; then
        spctl --assess --type execute "$app_path" >/dev/null 2>&1 || die "Gatekeeper assessment failed for $app_path."
    else
        warn "spctl not found; skipping Gatekeeper assessment."
    fi
}

find_utm_app_on_mount() {
    mount_dir="$1"
    find "$mount_dir" -maxdepth 3 -type d -name 'UTM.app' -print -quit
}

download_utm_dmg() {
    dmg_path="$1"
    have curl || die "curl is required to download UTM from GitHub."
    log "Downloading the latest free UTM DMG from the official GitHub release."
    run_cmd curl --fail --location --show-error --proto '=https' --tlsv1.2 --output "$dmg_path" "$UTM_GITHUB_DMG_URL"
}

copy_utm_app() {
    source_app="$1"
    target_app="$2"
    target_parent="$(dirname "$target_app")"

    have ditto || die "ditto is required to install UTM.app from the mounted DMG."
    if [ -L "$target_app" ]; then
        die "Refusing to overwrite symlinked UTM install target: $target_app"
    fi
    if [ -e "$target_app" ]; then
        die "Refusing to overwrite existing path: $target_app"
    fi

    run_cmd mkdir -p "$target_parent"
    log "Copying UTM.app to $target_app."
    run_cmd ditto "$source_app" "$target_app"
}

install_utm_web() {
    if existing_app="$(find_existing_utm_app)"; then
        log "UTM already appears to be installed at $existing_app."
        return 0
    fi
    open_utm_official_download_page
}

install_utm_github() {
    if existing_app="$(find_existing_utm_app)"; then
        log "UTM already appears to be installed at $existing_app."
        return 0
    fi

    target_app="$(utm_install_target_app)"
    if [ "$DRY_RUN" = true ]; then
        log "Would download the latest UTM DMG from $UTM_GITHUB_DMG_URL."
        run_cmd curl --fail --location --show-error --proto '=https' --tlsv1.2 --output "${TMPDIR:-/tmp}/UTM.dmg" "$UTM_GITHUB_DMG_URL"
        run_cmd hdiutil attach -nobrowse -readonly -mountpoint "${TMPDIR:-/tmp}/utm-install-mount" "${TMPDIR:-/tmp}/UTM.dmg"
        run_cmd mkdir -p "$(dirname "$target_app")"
        run_cmd ditto "${TMPDIR:-/tmp}/utm-install-mount/UTM.app" "$target_app"
        return 0
    fi

    have hdiutil || die "hdiutil is required to mount the UTM DMG."

    CLEANUP_UTM_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/utm-install.XXXXXX")" || die "Could not create a temporary directory for UTM download."
    CLEANUP_UTM_MOUNT_DIR="$CLEANUP_UTM_TMPDIR/mount"
    mkdir -p "$CLEANUP_UTM_MOUNT_DIR"
    dmg_path="$CLEANUP_UTM_TMPDIR/UTM.dmg"

    download_utm_dmg "$dmg_path"
    log "Mounting UTM DMG read-only."
    hdiutil attach -nobrowse -readonly -mountpoint "$CLEANUP_UTM_MOUNT_DIR" "$dmg_path" >/dev/null

    source_app="$(find_utm_app_on_mount "$CLEANUP_UTM_MOUNT_DIR")"
    [ -n "$source_app" ] || die "UTM.app was not found inside the downloaded DMG."

    verify_utm_app_bundle "$source_app"
    copy_utm_app "$source_app" "$target_app"
    verify_utm_app_bundle "$target_app"

    log "UTM installed from the official GitHub release to $target_app."
    cleanup_utm_download
    CLEANUP_UTM_TMPDIR=""
    CLEANUP_UTM_MOUNT_DIR=""
}

install_utm_brew() {
    have brew || die "Homebrew is required for --install-method brew. Install Homebrew first or use github/web."
    if utm_installed; then
        log "UTM already appears to be installed; skipping Homebrew cask install."
    elif brew list --cask utm >/dev/null 2>&1; then
        log "UTM Homebrew cask is already installed."
    else
        log "Installing UTM with Homebrew cask."
        run_cmd brew install --cask utm
    fi
}

install_utm() {
    case "$INSTALL_METHOD" in
        github|direct)
            install_utm_github
            ;;
        web|official|official-site)
            install_utm_web
            ;;
        brew)
            install_utm_brew
            ;;
        none)
            log "Skipping UTM install because --install-method none was selected."
            ;;
        *)
            die "Unknown --install-method: $INSTALL_METHOD (expected github, web, brew, or none)"
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
    if [ -d "$VOLUME/Backups.backupdb" ] || [ -d "$VOLUME/.backupdb" ]; then
        die "$VOLUME appears to contain Time Machine backup data. Use a dedicated UnsafeLab SSD, not a backup disk."
    fi
}

prepare_folders() {
    folders="VMs Raw-Quarantine Sanitized-Outbox Client-App-Tests Client-App-Tests/Transfer-Disks Logs"
    for folder in $folders; do
        path="$VOLUME/$folder"
        if [ -L "$path" ]; then
            die "Refusing to prepare symlinked lab folder: $path"
        fi
        run_cmd mkdir -p "$path"
        run_cmd chmod 700 "$path"
    done
}

exclude_time_machine() {
    if ! have tmutil; then
        warn "tmutil not found; add $VOLUME to Time Machine exclusions manually."
        return 0
    fi
    log "Adding Time Machine exclusions for $VOLUME and Raw-Quarantine."
    if ! run_cmd tmutil addexclusion -p "$VOLUME"; then
        warn "tmutil addexclusion failed for $VOLUME; add the volume in System Settings -> General -> Time Machine -> Options."
    fi
    if ! run_cmd tmutil addexclusion -p "$VOLUME/Raw-Quarantine"; then
        warn "tmutil addexclusion failed for Raw-Quarantine; add it in System Settings -> General -> Time Machine -> Options."
    fi
}

exclude_spotlight() {
    log "Adding Spotlight privacy markers for $VOLUME and Raw-Quarantine."
    run_cmd touch "$VOLUME/.metadata_never_index"
    run_cmd touch "$VOLUME/Raw-Quarantine/.metadata_never_index"
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
    [ "$WRITE_GUIDANCE_FILES" = true ] || return 0
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
- Periodically run utm-sandbox-audit.sh and utm-sandbox-inventory.sh from the host for read-only drift and stale-file review.
- Eject this volume when unsafe work is finished.

Review the full guide in the dotfiles repo:
  docs/utm-sandbox-macos.md
EOF
}

write_log_template() {
    [ "$WRITE_GUIDANCE_FILES" = true ] || return 0
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

write_folder_markers() {
    [ "$WRITE_GUIDANCE_FILES" = true ] || return 0
    if [ "$DRY_RUN" = true ]; then
        log "Would write Raw-Quarantine/Sanitized-Outbox/Transfer-Disks marker files"
        return 0
    fi
    cat >"$VOLUME/Raw-Quarantine/README-DO-NOT-OPEN.txt" <<'EOF'
Raw quarantine folder
=====================

Treat every file here as hostile. Do not open, Quick Look, preview, or upload
these files from the Mac host. Move raw files back into a disposable VM or a
no-internet transfer VM for scanning/sanitization.
EOF
    chmod 600 "$VOLUME/Raw-Quarantine/README-DO-NOT-OPEN.txt"

    cat >"$VOLUME/Sanitized-Outbox/README.txt" <<'EOF'
Sanitized outbox
================

Only sanitized outputs belong here. Do not place raw downloads or original client
archives in this folder. After copying a sanitized file to normal storage, remove
stale outbox copies you no longer need.
EOF
    chmod 600 "$VOLUME/Sanitized-Outbox/README.txt"

    cat >"$VOLUME/Client-App-Tests/README.txt" <<'EOF'
Client app tests
================

Use this area for notes, logs, screenshots, and sanitized outputs from dedicated
client-test VMs. Do not install unknown required clients on the Mac host just
because a website asks for them.
EOF
    chmod 600 "$VOLUME/Client-App-Tests/README.txt"

    cat >"$VOLUME/Client-App-Tests/Transfer-Disks/README-DO-NOT-MOUNT-ON-HOST.txt" <<'EOF'
Transfer disk images
====================

Intermediate .raw/.img/.qcow2 files in this folder are for attaching to dirty
and offline transfer VMs. Do not mount these disk images on the Mac host.
EOF
    chmod 600 "$VOLUME/Client-App-Tests/Transfer-Disks/README-DO-NOT-MOUNT-ON-HOST.txt"
}

write_vm_isolation_checklist() {
    [ "$WRITE_GUIDANCE_FILES" = true ] || return 0
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

write_transfer_vm_checklist() {
    [ "$WRITE_GUIDANCE_FILES" = true ] || return 0
    checklist_path="$VOLUME/Client-App-Tests/Transfer-VM-Checklist.md"
    if [ "$DRY_RUN" = true ]; then
        log "Would write $checklist_path"
        return 0
    fi
    cat >"$checklist_path" <<EOF
# No-internet transfer VM checklist

Use this checklist when moving candidate files from a dirty VM through an
offline transfer/sanitization VM before anything reaches Sanitized-Outbox.

- [ ] Transfer VM network is disconnected, Host Only with no internet route, or otherwise offline.
- [ ] Dirty VM is shut down before the transfer disk image is detached.
- [ ] Transfer disk image is attached only to the transfer VM after dirty VM shutdown.
- [ ] Transfer disk is mounted read-only when practical.
- [ ] Transfer VM has no clipboard sharing and no personal host folders.
- [ ] Shared folder, if enabled at all, is limited to ${VOLUME}/Sanitized-Outbox.
- [ ] Only sanitized PDFs/images/text outputs are copied to Sanitized-Outbox.
- [ ] Original archives, Office documents, executables, and raw PDFs remain off the Mac host.
- [ ] Transfer disk image is removed from UTM after the matter is closed.
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
    write_folder_markers
    write_vm_isolation_checklist
    write_transfer_vm_checklist
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
    if [ -L "$path" ]; then
        warn "$label is a symlink; expected a real directory on the encrypted UnsafeLab volume."
        return 1
    fi
    check_path "$label" "$path" || return 1
    mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
    if [ "$mode" = "700" ]; then
        log "OK: $label has owner-only permissions (700)."
        return 0
    fi
    warn "$label permissions are ${mode:-unknown}; expected 700 so other local users cannot browse lab files."
    return 1
}

check_private_file() {
    label="$1"
    path="$2"
    if [ -L "$path" ]; then
        warn "$label is a symlink; expected a real file on the encrypted UnsafeLab volume."
        return 1
    fi
    check_path "$label" "$path" || return 1
    mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
    if [ "$mode" = "600" ]; then
        log "OK: $label has owner-only permissions (600)."
        return 0
    fi
    warn "$label permissions are ${mode:-unknown}; expected 600."
    return 1
}

verify_time_machine() {
    if ! have tmutil; then
        warn "tmutil not found; cannot verify Time Machine exclusion."
        return 1
    fi
    out="$(tmutil isexcluded "$VOLUME" 2>/dev/null || true)"
    raw_out="$(tmutil isexcluded "$VOLUME/Raw-Quarantine" 2>/dev/null || true)"
    if printf '%s\n' "$out" | grep -Eiq '\[Excluded\]|is excluded' \
        && printf '%s\n' "$raw_out" | grep -Eiq '\[Excluded\]|is excluded'; then
        log "OK: Time Machine reports $VOLUME and Raw-Quarantine are excluded."
        return 0
    fi
    warn "Time Machine exclusion not confirmed for both $VOLUME and Raw-Quarantine."
    return 1
}

verify_spotlight() {
    if [ -e "$VOLUME/.metadata_never_index" ] && [ -e "$VOLUME/Raw-Quarantine/.metadata_never_index" ]; then
        log "OK: Spotlight markers exist at $VOLUME and Raw-Quarantine."
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

verify_filevault() {
    if ! have fdesetup; then
        warn "fdesetup not found; cannot verify FileVault status."
        return 0
    fi
    out="$(fdesetup status 2>/dev/null || true)"
    if printf '%s\n' "$out" | grep -Eiq 'FileVault is On|FileVault is enabled'; then
        log "OK: FileVault appears enabled."
    else
        warn "FileVault does not appear enabled; enable it for host data-at-rest protection."
    fi
}

verify_firewall() {
    firewall_cmd="/usr/libexec/ApplicationFirewall/socketfilterfw"
    if [ ! -x "$firewall_cmd" ]; then
        warn "socketfilterfw not found; cannot verify macOS firewall status."
        return 0
    fi
    out="$($firewall_cmd --getglobalstate 2>/dev/null || true)"
    if printf '%s\n' "$out" | grep -Eiq 'enabled'; then
        log "OK: macOS application firewall appears enabled."
    else
        warn "macOS application firewall does not appear enabled; enable it unless you have a specific reason not to."
    fi
}

verify_setup() {
    failures=0

    verify_filevault
    verify_firewall

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

    for file in \
        UnsafeLab-README.txt \
        VM-Isolation-Checklist.md \
        Client-App-Tests/Transfer-VM-Checklist.md \
        Logs/session-template.md \
        Raw-Quarantine/README-DO-NOT-OPEN.txt \
        Sanitized-Outbox/README.txt \
        Client-App-Tests/README.txt \
        Client-App-Tests/Transfer-Disks/README-DO-NOT-MOUNT-ON-HOST.txt; do
        if ! check_private_file "UnsafeLab/$file" "$VOLUME/$file"; then
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
            [ "$#" -ge 2 ] || die "--install-method requires github, web, brew, or none."
            INSTALL_METHOD="$2"
            shift
            ;;
        --install-dir)
            [ "$#" -ge 2 ] || die "--install-dir requires a path."
            INSTALL_DIR="$2"
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
        --no-guidance-files|--no-readme)
            WRITE_GUIDANCE_FILES=false
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
