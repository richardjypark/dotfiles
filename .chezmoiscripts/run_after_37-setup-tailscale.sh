#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}
eecho() { echo "$@"; }

vecho "Setting up Tailscale..."

# Fast exit if tailscale is already installed
if command -v tailscale >/dev/null 2>&1; then
    vecho "Tailscale is already installed: $(tailscale version 2>/dev/null | head -1 || echo 'installed')"
    exit 0
fi

# Detect OS for installation method
OS=$(uname -s)
vecho "Detected OS: $OS"

if [ "$OS" = "Darwin" ]; then
    # macOS: Use Homebrew
    if command -v brew >/dev/null 2>&1; then
        eecho "Installing Tailscale via Homebrew..."
        if [ "$VERBOSE" = "true" ]; then
            brew install --cask tailscale
        else
            brew install --cask tailscale >/dev/null 2>&1
        fi
    else
        eecho "Warning: Homebrew not available. Please install Tailscale from https://tailscale.com/download/mac"
        exit 0
    fi
elif [ "$OS" = "Linux" ]; then
    # Linux: Use official install script with retry
    eecho "Installing Tailscale via official install script..."
    if [ "$VERBOSE" = "true" ]; then
        curl -fsSL --retry 3 --retry-delay 2 https://tailscale.com/install.sh | sh
    else
        curl -fsSL --retry 3 --retry-delay 2 https://tailscale.com/install.sh | sh >/dev/null 2>&1
    fi
else
    eecho "Warning: Unsupported OS ($OS). Please install Tailscale manually from https://tailscale.com/download"
    exit 0
fi

# Verify installation
if command -v tailscale >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Tailscale installed successfully"
        tailscale version 2>/dev/null | head -1 || true
    fi
    eecho "Note: Run 'tailscale up' to authenticate and connect to your tailnet"
else
    eecho "Warning: Tailscale installation may not be complete. You may need to restart your shell."
fi

vecho "Tailscale setup complete!"
