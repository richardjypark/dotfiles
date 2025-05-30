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

# Only attempt package installations if we have sudo rights
if [ "$(id -u)" = 0 ] || is_installed sudo; then
    # Check if essential packages are missing
    MISSING_PACKAGES=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done

    # Only run apt-get if we actually need packages
    if [ -n "$MISSING_PACKAGES" ]; then
        eecho "Installing missing packages:$MISSING_PACKAGES"
        # Use apt-get only if it exists (Linux)
        if command -v apt-get >/dev/null 2>&1; then
            if [ "$(id -u)" = 0 ]; then
                apt-get update -qq
                echo "$MISSING_PACKAGES" | xargs -n1 | xargs -P4 apt-get install -y
            else
                sudo apt-get update -qq
                echo "$MISSING_PACKAGES" | xargs -n1 | sudo xargs -P4 apt-get install -y
            fi
        elif command -v brew >/dev/null 2>&1; then
            # macOS with Homebrew
            echo "$MISSING_PACKAGES" | xargs -n1 | xargs -P4 brew install
        else
            eecho "Warning: No supported package manager found. Please install packages manually."
        fi
    else
        vecho "All required packages are already installed"
    fi
else
    vecho "Note: Skipping package installation (no root/sudo access)"
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
