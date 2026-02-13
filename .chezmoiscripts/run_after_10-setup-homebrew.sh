#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

# Only run on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    vecho "Skipping Homebrew setup (not macOS)"
    exit 0
fi

vecho "Setting up Homebrew package management..."

# Install Homebrew if not present
if ! is_installed brew; then
    eecho "Installing Homebrew..."
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to run Homebrew installer without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow install.sh."
        exit 1
    fi
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    vecho "Homebrew is already installed"
fi

# Fast exit if all essential packages are installed
check_packages_installed() {
    local all_installed=true
    for pkg in "$@"; do
        if ! brew list "$pkg" &>/dev/null; then
            all_installed=false
            break
        fi
    done
    echo "$all_installed"
}

# Essential packages for development environment
ESSENTIAL_PACKAGES=(
    "git"
    "curl"
    "wget"
    "zsh"
)

# Optional development tools (only install if not present via other means)
OPTIONAL_PACKAGES=(
    "tmux"
    "fzf"
    "jq"
    "ripgrep"
    "bat"
    "eza"
    "fd"
    "gh"
)

if [ "${CHEZMOI_FORCE_UPDATE:-0}" != "1" ] && state_exists "homebrew-setup"; then
    if is_installed brew && [[ "$(check_packages_installed "${ESSENTIAL_PACKAGES[@]}")" == "true" ]] && [[ "${INSTALL_OPTIONAL_BREW_PACKAGES:-false}" != "true" ]]; then
        vecho "Homebrew setup already completed (state tracked)"
        exit 0
    fi
fi

# Check if all essential packages are installed
if [[ "$(check_packages_installed "${ESSENTIAL_PACKAGES[@]}")" == "true" ]]; then
    vecho "All essential Homebrew packages are already installed"
else
    eecho "Installing essential Homebrew packages..."

    # Update Homebrew
    vecho "Updating Homebrew..."
    brew update --quiet 2>/dev/null || brew update

    # Install essential packages
    for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! brew list "$pkg" &>/dev/null; then
            eecho "Installing $pkg..."
            brew install "$pkg" --quiet 2>/dev/null || brew install "$pkg"
        else
            vecho "$pkg is already installed"
        fi
    done
fi

# Install optional packages if explicitly requested
if [[ "${INSTALL_OPTIONAL_BREW_PACKAGES:-false}" == "true" ]]; then
    eecho "Installing optional development tools..."
    for pkg in "${OPTIONAL_PACKAGES[@]}"; do
        # Skip if already installed via other means (e.g., fzf via chezmoi external)
        if is_installed "$pkg" && ! brew list "$pkg" &>/dev/null; then
            vecho "Skipping $pkg (already installed via other means)"
            continue
        fi

        if ! brew list "$pkg" &>/dev/null; then
            eecho "Installing $pkg..."
            brew install "$pkg" --quiet 2>/dev/null || brew install "$pkg"
        else
            vecho "$pkg is already installed"
        fi
    done
fi

# Cleanup old versions
if [[ "${BREW_CLEANUP:-true}" == "true" ]]; then
    vecho "Cleaning up old Homebrew versions..."
    brew cleanup --quiet 2>/dev/null || brew cleanup
fi

if is_installed brew && [[ "$(check_packages_installed "${ESSENTIAL_PACKAGES[@]}")" == "true" ]]; then
    mark_state "homebrew-setup"
fi

vecho "Homebrew setup complete!"
