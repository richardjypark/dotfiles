#!/usr/bin/env bash
# chezmoi-helpers.sh — shared helper library for chezmoi scripts
# Sourced by all .chezmoiscripts/ files via: . "$HOME/.local/lib/chezmoi-helpers.sh"

# --- Output Helpers ---

VERBOSE="${VERBOSE:-false}"

vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

eecho() { echo "$@"; }

# --- State Tracking ---

STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"

# Ensure state directory exists (created once per apply run)
[ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"

# Check if a setup step was completed
state_exists() {
    [ -f "$STATE_DIR/$1.done" ]
}

# Mark a setup step as complete
mark_state() {
    touch "$STATE_DIR/$1.done"
}

# Clear a setup state (useful for forced re-runs)
clear_state() {
    rm -f "$STATE_DIR/$1.done"
}

# --- PATH Management ---

# Add a directory to PATH if not already present
add_to_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1:$PATH" ;;
    esac
}

# --- Command Detection ---

# Check if a command is available
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# --- Privilege Escalation ---

TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"

# Check if we can run privileged commands (root or passwordless sudo)
ensure_sudo() {
    if [ "$(id -u)" = 0 ]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    if [ "${CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO:-0}" = "1" ] && [ -t 0 ]; then
        eecho "Requesting sudo access for package installation..."
        sudo -v >/dev/null 2>&1 || return 1
        sudo -n true 2>/dev/null || return 1
        return 0
    fi
    return 1
}

# Run a command with privilege escalation if needed
run_privileged() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif ensure_sudo; then
        sudo "$@"
    else
        return 1
    fi
}
