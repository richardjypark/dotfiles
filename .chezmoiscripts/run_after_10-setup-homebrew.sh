#!/usr/bin/env bash
set -euo pipefail

# Quiet mode by default - only essential output unless VERBOSE is set
VERBOSE=${VERBOSE:-false}

# Function to print only if verbose
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

# Function to print essential information always
eecho() {
    echo "$@"
}

# Only run on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    vecho "Skipping Homebrew setup (not macOS)"
    exit 0
fi

vecho "Setting up Homebrew package management..."

# Function to check if Homebrew is installed
is_brew_installed() {
    command -v brew >/dev/null 2>&1
}

# Install Homebrew if not present
if ! is_brew_installed; then
    eecho "Installing Homebrew..."
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
        if command -v "$pkg" >/dev/null 2>&1 && ! brew list "$pkg" &>/dev/null; then
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

vecho "Homebrew setup complete!"
