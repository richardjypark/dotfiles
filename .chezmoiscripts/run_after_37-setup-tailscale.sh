#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if state_exists "tailscale-setup"; then
    vecho "Tailscale setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Tailscale..."

# Fast exit if tailscale is already installed (but mark state)
if is_installed tailscale; then
    vecho "Tailscale is already installed: $(tailscale version 2>/dev/null | head -1 || echo 'installed')"
    mark_state "tailscale-setup"
    exit 0
fi

# Detect OS for installation method
OS=$(uname -s)
vecho "Detected OS: $OS"

if [ "$OS" = "Darwin" ]; then
    # macOS: Use Homebrew
    if is_installed brew; then
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
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to run remote installer without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow tailscale.com/install.sh."
        exit 1
    fi
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
if is_installed tailscale; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Tailscale installed successfully"
        tailscale version 2>/dev/null | head -1 || true
    fi
    eecho "Note: Run 'tailscale up' to authenticate and connect to your tailnet"
    mark_state "tailscale-setup"
else
    eecho "Error: Tailscale installation failed. Leaving state unset so it can retry."
    exit 1
fi

vecho "Tailscale setup complete!"
