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

# Check if a setup step was completed
state_exists() {
    [ -f "$STATE_DIR/$1.done" ]
}

# Mark a setup step as complete
mark_state() {
    mkdir -p "$STATE_DIR" || return 1
    touch "$STATE_DIR/$1.done"
}

# Clear a setup state (useful for forced re-runs)
clear_state() {
    rm -f "$STATE_DIR/$1.done"
}

is_force_update() {
    [ "${CHEZMOI_FORCE_UPDATE:-0}" = "1" ]
}

is_macos_maintenance_mode() {
    [ "${CHEZMOI_MACOS_MAINTENANCE_MODE:-0}" = "1" ]
}

should_skip_state() {
    local state_name="$1"
    if state_exists "$state_name" && ! is_force_update; then
        return 0
    fi
    return 1
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

# Shared Homebrew formula flow. The caller selects whether quiet mode retries
# without --quiet, preserving package-specific fallback behavior.
brew_install_formula() {
    local formula="$1" label="$2" quiet_retry="${3:-false}" action="install"
    is_installed brew || return 1

    if brew list --formula "$formula" >/dev/null 2>&1; then
        if ! brew outdated --formula "$formula" 2>/dev/null \
            | awk -v formula="$formula" '$1 == formula { found = 1 } END { exit !found }'; then
            eecho "$label already at latest Homebrew version"
            return 0
        fi
        action="upgrade"
    fi

    eecho "Running brew $action for $label..."
    if [ "$VERBOSE" = "true" ]; then
        brew "$action" "$formula"
    elif [ "$quiet_retry" = "true" ]; then
        brew "$action" "$formula" --quiet >/dev/null 2>&1 || brew "$action" "$formula"
    else
        brew "$action" "$formula" >/dev/null 2>&1
    fi
}

# --- Privilege Escalation ---

TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"
CHEZMOI_DISABLE_SUDO="${CHEZMOI_DISABLE_SUDO:-0}"

# Download/cache settings
CHEZMOI_PREFETCH_JOBS="${CHEZMOI_PREFETCH_JOBS:-4}"
CHEZMOI_DOWNLOAD_CACHE_DIR="${CHEZMOI_DOWNLOAD_CACHE_DIR:-$HOME/.cache/chezmoi-downloads}"

sudo_disabled() {
    case "${CHEZMOI_DISABLE_SUDO:-0}" in
        1|true|TRUE|yes|YES)
            return 0
            ;;
    esac
    return 1
}

# Check if we can run privileged commands (root or passwordless sudo)
ensure_sudo() {
    if sudo_disabled; then
        return 1
    fi
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
    if sudo_disabled; then
        return 1
    fi
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif ensure_sudo; then
        sudo "$@"
    else
        return 1
    fi
}

require_trust_for_remote_installer() {
    local installer="$1"
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to run remote installer without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow ${installer}."
        return 1
    fi
    return 0
}

require_trust_for_remote_download() {
    local source="$1"
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to fetch remote artifact without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow download from ${source}."
        return 1
    fi
    return 0
}

# --- Convenience Wrappers ---

# Run a command, suppressing stdout/stderr unless VERBOSE=true.
# Usage: run_quiet cmd arg1 arg2 ...
run_quiet() {
    local output_file status
    if [ "$VERBOSE" = "true" ]; then
        "$@"
        return $?
    fi
    output_file="$(mktemp "${TMPDIR:-/tmp}/chezmoi-command.XXXXXXXX")" || {
        "$@"
        return $?
    }
    if "$@" >"$output_file" 2>&1; then
        rm -f "$output_file"
        return 0
    else
        status=$?
        printf 'Command failed (exit %s): %s\n' "$status" "$1" >&2
        tail -n 80 "$output_file" >&2
        rm -f "$output_file"
        return "$status"
    fi
}

# --- Version Comparison ---

# Generic semver comparison (MAJOR.MINOR.PATCH).
# Returns 0 (true) if $1 >= $2, 1 (false) otherwise.
# Usage: version_ge "1.2.3" "1.2.0" && echo "ok"
version_ge() {
    local current required
    local c1 c2 c3 r1 r2 r3

    current="${1:-0.0.0}"
    required="${2:-0.0.0}"

    IFS=. read -r c1 c2 c3 <<EOF
$current
EOF
    IFS=. read -r r1 r2 r3 <<EOF
$required
EOF

    c1=${c1:-0}; c2=${c2:-0}; c3=${c3:-0}
    r1=${r1:-0}; r2=${r2:-0}; r3=${r3:-0}

    if [ "$c1" -gt "$r1" ]; then return 0; fi
    if [ "$c1" -lt "$r1" ]; then return 1; fi
    if [ "$c2" -gt "$r2" ]; then return 0; fi
    if [ "$c2" -lt "$r2" ]; then return 1; fi
    if [ "$c3" -ge "$r3" ]; then return 0; fi
    return 1
}

normalize_version_token() {
    local value="${1:-}"
    value="${value#rust-v}"
    value="${value#bun-v}"
    value="${value#v}"
    value="${value%%-*}"
    printf '%s\n' "$value"
}
