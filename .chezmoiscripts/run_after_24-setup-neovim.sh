#!/usr/bin/env bash
set -euo pipefail

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}
eecho() { echo "$@"; }

# State tracking
STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"
STATE_FILE="$STATE_DIR/neovim-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Neovim setup already completed (state tracked)"
    exit 0
fi

# Ensure ~/.local/bin is in PATH
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Fast exit if nvim is already installed (but mark state)
if command -v nvim >/dev/null 2>&1; then
    vecho "Neovim is already installed: $(nvim --version | sed -n '1p' 2>/dev/null || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

# Helper function to run commands with sudo if needed (non-interactively)
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

run_privileged() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif ensure_sudo; then
        sudo "$@"
    else
        return 1
    fi
}

install_via_package_manager() {
    # If we cannot run privileged package manager commands, let caller try other methods.
    if [ "$(id -u)" != 0 ] && ! ensure_sudo; then
        vecho "Skipping package manager install (sudo unavailable)"
        return 1
    fi

    if command -v pacman >/dev/null 2>&1; then
        eecho "Installing Neovim via pacman..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged pacman -Sy --noconfirm neovim
        else
            run_privileged pacman -Sy --noconfirm --quiet neovim >/dev/null 2>&1
        fi
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        eecho "Installing Neovim via apt-get..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged apt-get update
            run_privileged apt-get install -y neovim
        else
            run_privileged apt-get update -qq
            run_privileged apt-get install -y -qq neovim
        fi
        return 0
    fi

    if command -v dnf >/dev/null 2>&1; then
        eecho "Installing Neovim via dnf..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged dnf install -y neovim
        else
            run_privileged dnf install -y -q neovim >/dev/null 2>&1
        fi
        return 0
    fi

    if command -v yum >/dev/null 2>&1; then
        eecho "Installing Neovim via yum..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged yum install -y neovim
        else
            run_privileged yum install -y -q neovim >/dev/null 2>&1
        fi
        return 0
    fi

    if command -v zypper >/dev/null 2>&1; then
        eecho "Installing Neovim via zypper..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged zypper install -y neovim
        else
            run_privileged zypper install -y neovim >/dev/null 2>&1
        fi
        return 0
    fi

    if command -v apk >/dev/null 2>&1; then
        eecho "Installing Neovim via apk..."
        if [ "$VERBOSE" = "true" ]; then
            run_privileged apk add neovim
        else
            run_privileged apk add neovim >/dev/null 2>&1
        fi
        return 0
    fi

    return 1
}

install_via_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        return 1
    fi

    eecho "Installing Neovim via Homebrew..."
    if [ "$VERBOSE" = "true" ]; then
        brew install neovim
    else
        brew install neovim >/dev/null 2>&1
    fi
    return 0
}

install_via_release_binary() {
    local os arch latest_version archive_name download_url temp_dir root_dir install_root

    case "$(uname -s)" in
        Linux) os="linux" ;;
        Darwin) os="macos" ;;
        *)
            eecho "Unsupported OS for binary Neovim install: $(uname -s)"
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            eecho "Unsupported architecture for binary Neovim install: $(uname -m)"
            return 1
            ;;
    esac

    latest_version="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p')"
    if [ -z "$latest_version" ]; then
        eecho "Error: Could not determine latest Neovim release version."
        return 1
    fi

    case "${os}-${arch}" in
        linux-x86_64) archive_name="nvim-linux-x86_64.tar.gz" ;;
        linux-arm64) archive_name="nvim-linux-arm64.tar.gz" ;;
        macos-x86_64) archive_name="nvim-macos-x86_64.tar.gz" ;;
        macos-arm64) archive_name="nvim-macos-arm64.tar.gz" ;;
        *)
            eecho "Unsupported release-binary target: ${os}-${arch}"
            return 1
            ;;
    esac

    download_url="https://github.com/neovim/neovim/releases/download/${latest_version}/${archive_name}"
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    eecho "Installing Neovim from release binary (${latest_version})..."
    if [ "$VERBOSE" = "true" ]; then
        curl -fL --retry 3 --retry-delay 2 "$download_url" -o "$temp_dir/nvim.tar.gz"
    else
        curl -fLsS --retry 3 --retry-delay 2 "$download_url" -o "$temp_dir/nvim.tar.gz"
    fi

    tar -xzf "$temp_dir/nvim.tar.gz" -C "$temp_dir"
    root_dir="$(tar -tzf "$temp_dir/nvim.tar.gz" | sed -n '1p' | cut -d/ -f1)"
    if [ -z "$root_dir" ] || [ ! -d "$temp_dir/$root_dir" ]; then
        eecho "Error: Could not determine extracted Neovim directory."
        return 1
    fi

    install_root="$HOME/.local/neovim"
    mkdir -p "$HOME/.local/bin"
    rm -rf "$install_root"
    mv "$temp_dir/$root_dir" "$install_root"
    ln -sf "$install_root/bin/nvim" "$HOME/.local/bin/nvim"
    return 0
}

if install_via_package_manager; then
    vecho "Neovim installation method: package manager"
elif install_via_homebrew; then
    vecho "Neovim installation method: homebrew"
elif install_via_release_binary; then
    vecho "Neovim installation method: release binary"
else
    eecho "Error: Could not install Neovim automatically."
    eecho "Please install Neovim manually from https://neovim.io/ and rerun chezmoi apply."
    exit 1
fi

# Verify installation
if command -v nvim >/dev/null 2>&1 && nvim --version >/dev/null 2>&1; then
    vecho "Neovim installed successfully: $(nvim --version | sed -n '1p')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    eecho "Error: Neovim installation failed. Leaving state unset so it can retry."
    exit 1
fi

