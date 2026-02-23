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
    if ! require_trust_for_remote_installer "Homebrew install.sh"; then
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

# Cache formula list once per run to avoid repeated brew list calls.
BREW_INSTALLED_FORMULAE=""
refresh_brew_formulae_cache() {
    BREW_INSTALLED_FORMULAE="$(brew list --formula 2>/dev/null || true)"
}

brew_formula_installed() {
    local pkg="$1"
    printf '%s\n' "$BREW_INSTALLED_FORMULAE" | grep -Fxq "$pkg"
}

# Fast exit if all essential packages are installed.
check_packages_installed() {
    local pkg
    for pkg in "$@"; do
        if ! brew_formula_installed "$pkg"; then
            return 1
        fi
    done
    return 0
}

# Essential packages for development environment
ESSENTIAL_PACKAGES=(
    "git"
    "curl"
    "wget"
    "zsh"
    "coreutils"
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

if should_skip_state "homebrew-setup"; then
    refresh_brew_formulae_cache
    if is_installed brew && check_packages_installed "${ESSENTIAL_PACKAGES[@]}" && [[ "${INSTALL_OPTIONAL_BREW_PACKAGES:-false}" != "true" ]]; then
        vecho "Homebrew setup already completed (state tracked)"
        exit 0
    fi
fi

refresh_brew_formulae_cache

# Check if all essential packages are installed
if check_packages_installed "${ESSENTIAL_PACKAGES[@]}"; then
    vecho "All essential Homebrew packages are already installed"
else
    eecho "Installing essential Homebrew packages..."

    # Update Homebrew
    vecho "Updating Homebrew..."
    brew update --quiet 2>/dev/null || brew update

    # Install essential packages
    for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! brew_formula_installed "$pkg"; then
            eecho "Installing $pkg..."
            brew install "$pkg" --quiet 2>/dev/null || brew install "$pkg"
            refresh_brew_formulae_cache
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
        if is_installed "$pkg" && ! brew_formula_installed "$pkg"; then
            vecho "Skipping $pkg (already installed via other means)"
            continue
        fi

        if ! brew_formula_installed "$pkg"; then
            eecho "Installing $pkg..."
            brew install "$pkg" --quiet 2>/dev/null || brew install "$pkg"
            refresh_brew_formulae_cache
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

refresh_brew_formulae_cache
if is_installed brew && check_packages_installed "${ESSENTIAL_PACKAGES[@]}"; then
    mark_state "homebrew-setup"
fi

vecho "Homebrew setup complete!"
