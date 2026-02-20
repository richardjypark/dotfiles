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

is_force_update() {
    [ "${CHEZMOI_FORCE_UPDATE:-0}" = "1" ]
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

# --- Privilege Escalation ---

TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"

# Download/cache settings
CHEZMOI_PREFETCH_JOBS="${CHEZMOI_PREFETCH_JOBS:-4}"
CHEZMOI_DOWNLOAD_CACHE_DIR="${CHEZMOI_DOWNLOAD_CACHE_DIR:-$HOME/.cache/chezmoi-downloads}"

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

detect_normalized_os() {
    case "$(uname -s)" in
        Linux) printf '%s\n' "linux" ;;
        Darwin) printf '%s\n' "macos" ;;
        *)
            eecho "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
}

detect_normalized_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' "x86_64" ;;
        aarch64|arm64) printf '%s\n' "arm64" ;;
        *)
            eecho "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

detect_platform() {
    local os arch
    os="$(detect_normalized_os)" || return 1
    arch="$(detect_normalized_arch)" || return 1
    printf '%s %s\n' "$os" "$arch"
}

platform_key() {
    local os arch
    if ! read -r os arch <<EOF
$(detect_platform)
EOF
    then
        return 1
    fi
    printf '%s-%s\n' "$os" "$arch"
}

sha256_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi
    eecho "Error: no SHA-256 tool found (need sha256sum or shasum)."
    return 1
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual

    if [ ! -f "$file" ]; then
        return 1
    fi

    actual="$(sha256_file "$file")" || return 1
    [ "$actual" = "$expected" ]
}

download_file() {
    local url="$1"
    local destination="$2"
    local destination_dir
    destination_dir="$(dirname "$destination")"
    mkdir -p "$destination_dir"

    curl --fail --location --show-error --silent \
        --proto '=https' --tlsv1.2 \
        --retry 3 --retry-delay 2 \
        --connect-timeout 10 --max-time 300 \
        "$url" -o "$destination"
}

download_and_verify() {
    local url="$1"
    local destination="$2"
    local expected_sha="$3"
    local tmp_file

    if [ -f "$destination" ] && verify_sha256 "$destination" "$expected_sha"; then
        vecho "Using verified cached artifact: $destination"
        return 0
    fi

    if [ -f "$destination" ]; then
        vecho "Cached artifact checksum mismatch, re-downloading: $destination"
    else
        vecho "Cache miss, downloading artifact: $destination"
    fi

    tmp_file="${destination}.tmp.$$"
    rm -f "$tmp_file"
    download_file "$url" "$tmp_file"

    if ! verify_sha256 "$tmp_file" "$expected_sha"; then
        eecho "Error: checksum verification failed for $url"
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$destination"
    vecho "Downloaded and verified artifact: $destination"
    return 0
}
