#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

REQUIRED_NVIM_VERSION="${REQUIRED_NVIM_VERSION:-0.11.2}"

get_nvim_version() {
    if ! is_installed nvim; then
        return 1
    fi
    nvim --version 2>/dev/null | sed -n '1s/^NVIM v//p' | awk '{print $1}'
}

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

nvim_meets_requirement() {
    local version
    version="$(get_nvim_version || true)"
    [ -n "$version" ] && version_ge "$version" "$REQUIRED_NVIM_VERSION"
}

# Fast exit if already completed via state tracking
if state_exists "neovim-setup"; then
    if nvim_meets_requirement; then
        vecho "Neovim setup already completed (state tracked)"
        exit 0
    fi
    eecho "Neovim state exists but version is below ${REQUIRED_NVIM_VERSION}; re-running setup..."
fi

add_to_path "$HOME/.local/bin"

# Fast exit if nvim is already installed with required version (but mark state)
if nvim_meets_requirement; then
    vecho "Neovim is already installed and up to date: $(nvim --version | sed -n '1p' 2>/dev/null || echo 'installed')"
    mark_state "neovim-setup"
    exit 0
fi

if is_installed nvim; then
    eecho "Detected Neovim $(get_nvim_version), upgrading to >= ${REQUIRED_NVIM_VERSION} for LazyVim compatibility..."
fi

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
    if ! is_installed brew; then
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
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to download Neovim release binary without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow GitHub release download."
        return 1
    fi

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
    if nvim_meets_requirement; then
        vecho "Neovim installation method: package manager"
    else
        eecho "Package manager Neovim version is below ${REQUIRED_NVIM_VERSION}; trying newer install method..."
        if install_via_homebrew; then
            vecho "Neovim installation method: homebrew"
        elif install_via_release_binary; then
            vecho "Neovim installation method: release binary"
        else
            eecho "Error: Could not install Neovim >= ${REQUIRED_NVIM_VERSION} automatically."
            eecho "Please install a newer Neovim manually from https://neovim.io/ and rerun chezmoi apply."
            exit 1
        fi
    fi
elif install_via_homebrew; then
    vecho "Neovim installation method: homebrew"
elif install_via_release_binary; then
    vecho "Neovim installation method: release binary"
else
    eecho "Error: Could not install Neovim >= ${REQUIRED_NVIM_VERSION} automatically."
    eecho "Please install a newer Neovim manually from https://neovim.io/ and rerun chezmoi apply."
    exit 1
fi

# Verify installation
if nvim_meets_requirement; then
    vecho "Neovim installed successfully: $(nvim --version | sed -n '1p')"
    mark_state "neovim-setup"
else
    if is_installed nvim; then
        eecho "Error: Neovim $(get_nvim_version) is still below required ${REQUIRED_NVIM_VERSION}."
    else
        eecho "Error: Neovim installation failed."
    fi
    eecho "Leaving state unset so setup can retry."
    exit 1
fi
