has_user_systemd() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

gateway_state_satisfied() {
    if [ -e "$GATEWAY_MARKER_FILE" ]; then
        has_user_systemd || return 1
        systemctl --user is-enabled --quiet "$SERVICE_UNIT" || return 1
        systemctl --user is-active --quiet "$SERVICE_UNIT" || return 1
        return 0
    fi

    if has_user_systemd; then
        if systemctl --user is-enabled --quiet "$SERVICE_UNIT" 2>/dev/null \
            || systemctl --user is-active --quiet "$SERVICE_UNIT" 2>/dev/null; then
            return 1
        fi
    fi
    return 0
}

disable_gateway_service_if_needed() {
    has_user_systemd || return 0
    if systemctl --user is-enabled --quiet "$SERVICE_UNIT" 2>/dev/null \
        || systemctl --user is-active --quiet "$SERVICE_UNIT" 2>/dev/null; then
        eecho "Disabling Hermes gateway user service (marker not present)..."
        systemctl --user disable --now "$SERVICE_UNIT" >/dev/null 2>&1 || true
    fi
}

ensure_gateway_service() {
    if [ ! -e "$GATEWAY_MARKER_FILE" ]; then
        disable_gateway_service_if_needed
        return 0
    fi

    if ! has_user_systemd; then
        eecho "Hermes Agent is installed, but user systemd is unavailable; gateway service not started."
        eecho "Rerun chezmoi apply from a normal login session or enable linger for this user."
        return 0
    fi

    eecho "Ensuring Hermes gateway user service is enabled for this always-on host..."
    # Hermes 0.15 prompts before starting/enabling the service; keep chezmoi
    # non-interactive and let the explicit systemctl call below enforce state.
    printf 'n\nn\n' | run_quiet run_hermes_cli gateway install
    systemctl --user daemon-reload
    if [ "$VERBOSE" = "true" ]; then
        systemctl --user enable --now "$SERVICE_UNIT"
    else
        systemctl --user enable --now "$SERVICE_UNIT" >/dev/null 2>&1
    fi
}
