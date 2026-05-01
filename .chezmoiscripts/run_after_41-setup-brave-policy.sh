#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

BRAVE_POLICY_PLIST="/Library/Managed Preferences/com.brave.Browser.plist"

write_empty_policy_plist() {
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
PLIST
}

write_brave_tor_policy_plist() {
    cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>TorDisabled</key>
  <true/>
</dict>
</plist>
PLIST
}

current_policy_value() {
    if [ ! -r "$BRAVE_POLICY_PLIST" ]; then
        return 0
    fi
    /usr/libexec/PlistBuddy -c "Print :TorDisabled" "$BRAVE_POLICY_PLIST" 2>/dev/null || true
}

if [ "$(uname -s)" != "Darwin" ]; then
    vecho "Skipping Brave policy setup on non-macOS host"
    exit 0
fi

if [ "$(current_policy_value)" = "true" ]; then
    vecho "Brave Tor policy already applied"
    exit 0
fi

if ! ensure_sudo; then
    eecho "Warning: Cannot apply Brave Tor policy without sudo access."
    eecho "Expected policy path: $BRAVE_POLICY_PLIST"
    exit 0
fi

tmp_policy="$(mktemp)"
trap 'rm -f "$tmp_policy"' EXIT

run_privileged install -d -m 0755 "$(dirname "$BRAVE_POLICY_PLIST")"

if [ ! -f "$BRAVE_POLICY_PLIST" ]; then
    write_empty_policy_plist >"$tmp_policy"
    run_privileged install -m 0644 "$tmp_policy" "$BRAVE_POLICY_PLIST"
fi

if ! run_privileged /usr/libexec/PlistBuddy -c "Set :TorDisabled true" "$BRAVE_POLICY_PLIST" >/dev/null 2>&1; then
    if ! run_privileged /usr/libexec/PlistBuddy -c "Add :TorDisabled bool true" "$BRAVE_POLICY_PLIST" >/dev/null 2>&1; then
        write_brave_tor_policy_plist >"$tmp_policy"
        run_privileged install -m 0644 "$tmp_policy" "$BRAVE_POLICY_PLIST"
    fi
fi

run_privileged chown root:wheel "$BRAVE_POLICY_PLIST"
run_privileged chmod 0644 "$BRAVE_POLICY_PLIST"
run_privileged plutil -convert xml1 "$BRAVE_POLICY_PLIST" >/dev/null 2>&1 || true

eecho "Applied Brave macOS policy: TorDisabled=true"
