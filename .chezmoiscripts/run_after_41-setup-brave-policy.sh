#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

BRAVE_POLICY_DOMAIN="com.brave.Browser"
BRAVE_POLICY_KEY="TorDisabled"

# If someone accidentally runs chezmoi through sudo, still target the login
# user whose Brave profile should be managed.
if [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER:-}" != "root" ]; then
    BRAVE_POLICY_USER="$SUDO_USER"
else
    BRAVE_POLICY_USER="$(id -un)"
fi

BRAVE_POLICY_RECORD="/Users/${BRAVE_POLICY_USER}"
BRAVE_POLICY_PLIST="/Library/Managed Preferences/${BRAVE_POLICY_USER}/${BRAVE_POLICY_DOMAIN}.plist"

write_brave_tor_policy_plist() {
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>${BRAVE_POLICY_KEY}</key>
  <true/>
</dict>
</plist>
PLIST
}

current_policy_value() {
    if [ ! -r "$BRAVE_POLICY_PLIST" ]; then
        return 0
    fi
    /usr/libexec/PlistBuddy -c "Print :${BRAVE_POLICY_KEY}" "$BRAVE_POLICY_PLIST" 2>/dev/null || true
}

mcx_policy_value() {
    dscl . -mcxread "$BRAVE_POLICY_RECORD" "$BRAVE_POLICY_DOMAIN" "$BRAVE_POLICY_KEY" 2>/dev/null || true
}

mcx_policy_applied() {
    local value
    value="$(mcx_policy_value)"
    [ -n "$value" ] || return 1
    printf '%s\n' "$value" | grep -qi "always" || return 1
    printf '%s\n' "$value" | grep -Eiq "(-bool 1|true|<true/>)"
}

persist_mcx_policy() {
    if ! run_privileged dscl . -read "$BRAVE_POLICY_RECORD" >/dev/null 2>&1; then
        eecho "Warning: Cannot find local Directory Services record: $BRAVE_POLICY_RECORD"
        return 1
    fi

    # /Library/Managed Preferences is an MCX cache. Direct plist writes can be
    # discarded when macOS rebuilds managed preferences at login/reboot, so make
    # the local Directory Services MCXSettings record the durable source.
    run_privileged dscl . -mcxset "$BRAVE_POLICY_RECORD" "$BRAVE_POLICY_DOMAIN" "$BRAVE_POLICY_KEY" always -bool 1

    if command -v mcxrefresh >/dev/null 2>&1; then
        run_privileged mcxrefresh -n "$BRAVE_POLICY_USER" >/dev/null 2>&1 || true
    fi
}

materialize_managed_policy_plist() {
    local tmp_policy
    tmp_policy="$(mktemp)"

    run_privileged install -d -m 0755 "$(dirname "$BRAVE_POLICY_PLIST")"

    if [ ! -f "$BRAVE_POLICY_PLIST" ]; then
        write_brave_tor_policy_plist >"$tmp_policy"
        run_privileged install -m 0644 "$tmp_policy" "$BRAVE_POLICY_PLIST"
    else
        if ! run_privileged plutil -lint "$BRAVE_POLICY_PLIST" >/dev/null; then
            eecho "Error: $BRAVE_POLICY_PLIST is not a valid plist; refusing to overwrite existing Brave managed policies."
            return 1
        fi
        if ! run_privileged /usr/libexec/PlistBuddy -c "Set :${BRAVE_POLICY_KEY} true" "$BRAVE_POLICY_PLIST" >/dev/null 2>&1; then
            run_privileged /usr/libexec/PlistBuddy -c "Add :${BRAVE_POLICY_KEY} bool true" "$BRAVE_POLICY_PLIST" >/dev/null
        fi
    fi

    run_privileged chown root:wheel "$BRAVE_POLICY_PLIST"
    run_privileged chmod 0644 "$BRAVE_POLICY_PLIST"
    run_privileged plutil -convert xml1 "$BRAVE_POLICY_PLIST" >/dev/null 2>&1 || true
    rm -f "$tmp_policy"
}

if [ "$(uname -s)" != "Darwin" ]; then
    vecho "Skipping Brave policy setup on non-macOS host"
    exit 0
fi

POLICY_CACHE_ALREADY_APPLIED=false
if [ "$(current_policy_value)" = "true" ]; then
    POLICY_CACHE_ALREADY_APPLIED=true
fi

PERSISTENT_MCX_ALREADY_APPLIED=false
if mcx_policy_applied; then
    PERSISTENT_MCX_ALREADY_APPLIED=true
fi

if [ "$POLICY_CACHE_ALREADY_APPLIED" = "true" ] && [ "$PERSISTENT_MCX_ALREADY_APPLIED" = "true" ]; then
    vecho "Brave Tor policy already applied"
    exit 0
fi

if ! ensure_sudo; then
    eecho "Warning: Cannot persist Brave Tor policy without sudo access."
    eecho "Run: sudo -v && chezmoi apply --include=scripts --source-path .chezmoiscripts/run_after_41-setup-brave-policy.sh"
    eecho "Expected managed policy path: $BRAVE_POLICY_PLIST"
    exit 0
fi

persist_mcx_policy
materialize_managed_policy_plist
run_privileged killall cfprefsd >/dev/null 2>&1 || true

eecho "Applied persistent Brave macOS policy: ${BRAVE_POLICY_KEY}=true"
