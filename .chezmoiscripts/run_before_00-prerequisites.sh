#!/bin/sh
set -e

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

vecho "Checking prerequisites..."

# Function to check if a package is installed
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Fast exit if all essential tools are already available
if is_installed zsh && is_installed git && is_installed curl && is_installed chezmoi; then
    vecho "All essential prerequisites are already installed"
    exit 0
fi

# Helper function to run commands with sudo if needed (non-interactively)
run_privileged() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif sudo -n true 2>/dev/null; then
        sudo "$@"
    else
        return 1
    fi
}

# Check if we can run privileged commands
CAN_SUDO=false
if [ "$(id -u)" = 0 ]; then
    CAN_SUDO=true
elif sudo -n true 2>/dev/null; then
    CAN_SUDO=true
fi

# Only attempt package installations if we have passwordless sudo rights
if [ "$CAN_SUDO" = "true" ]; then
    # Check if essential packages are missing
    MISSING_PACKAGES=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done

    # Only install if we actually need packages
    if [ -n "$MISSING_PACKAGES" ]; then
        eecho "Installing missing packages:$MISSING_PACKAGES"

        if command -v apt-get >/dev/null 2>&1; then
            # Debian/Ubuntu
            run_privileged apt-get update -qq
            for pkg in $MISSING_PACKAGES; do
                run_privileged apt-get install -y -qq "$pkg"
            done
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora/RHEL/CentOS
            for pkg in $MISSING_PACKAGES; do
                run_privileged dnf install -y -q "$pkg"
            done
        elif command -v yum >/dev/null 2>&1; then
            # Older RHEL/CentOS
            for pkg in $MISSING_PACKAGES; do
                run_privileged yum install -y -q "$pkg"
            done
        elif command -v pacman >/dev/null 2>&1; then
            # Arch Linux
            run_privileged pacman -Sy --noconfirm --quiet $MISSING_PACKAGES
        elif command -v zypper >/dev/null 2>&1; then
            # openSUSE
            run_privileged zypper install -y -q $MISSING_PACKAGES
        elif command -v apk >/dev/null 2>&1; then
            # Alpine Linux
            run_privileged apk add --quiet $MISSING_PACKAGES
        elif command -v brew >/dev/null 2>&1; then
            # macOS with Homebrew
            for pkg in $MISSING_PACKAGES; do
                brew install --quiet "$pkg"
            done
        else
            eecho "Warning: No supported package manager found. Please install packages manually:"
            eecho "  $MISSING_PACKAGES"
        fi
    else
        vecho "All required packages are already installed"
    fi
else
    # Check if any packages are actually missing before warning
    MISSING=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING="$MISSING $pkg"
        fi
    done
    if [ -n "$MISSING" ]; then
        eecho "Note: Cannot install packages without passwordless sudo:$MISSING"
    else
        vecho "All required packages are already installed"
    fi
fi

# Create directories if they don't exist (no root needed)
for dir in "$HOME/.local/bin" "$HOME/.local/share"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        vecho "Created directory: $dir"
    fi
done

# Add .local/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    if ! grep -q '$HOME/.local/bin' "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.profile"
        vecho "Added .local/bin to PATH"
    fi
fi

# Install chezmoi only if not present
if ! is_installed chezmoi; then
    eecho "Installing chezmoi..."
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
else
    vecho "chezmoi is already installed"
fi

vecho "Prerequisites check complete!"
