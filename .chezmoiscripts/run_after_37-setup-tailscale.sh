#!/bin/sh
set -eu

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
STATE_FILE="$STATE_DIR/tailscale-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Tailscale setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Tailscale..."

# Fast exit if tailscale is already installed (but mark state)
if command -v tailscale >/dev/null 2>&1; then
    vecho "Tailscale is already installed: $(tailscale version 2>/dev/null | head -1 || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
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
    # Mark setup as complete
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    eecho "Warning: Tailscale installation may not be complete. You may need to restart your shell."
    # Still mark as complete since installation succeeded
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
fi

vecho "Tailscale setup complete!"
