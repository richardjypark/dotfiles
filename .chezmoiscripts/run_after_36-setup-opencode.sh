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

vecho "Setting up OpenCode..."

# Fast exit if opencode is already installed
if command -v opencode >/dev/null 2>&1; then
    vecho "OpenCode is already installed: $(opencode --version 2>/dev/null || echo 'installed')"
    exit 0
fi

# Detect OS for installation method preference
OS=$(uname -s)
vecho "Detected OS: $OS"

# Prefer Homebrew on macOS, curl install script as fallback on Linux
if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    eecho "Installing OpenCode via Homebrew..."
    if [ "$VERBOSE" = "true" ]; then
        brew install sst/tap/opencode
    else
        brew install sst/tap/opencode >/dev/null 2>&1
    fi
elif command -v npm >/dev/null 2>&1; then
    eecho "Installing OpenCode via npm..."
    if [ "$VERBOSE" = "true" ]; then
        npm install -g opencode-ai
    else
        npm install -g opencode-ai >/dev/null 2>&1
    fi
else
    # Fallback: Use the official install script
    eecho "Installing OpenCode via official install script..."
    if [ "$VERBOSE" = "true" ]; then
        curl -fsSL https://opencode.ai/install | bash
    else
        curl -fsSL https://opencode.ai/install | bash >/dev/null 2>&1
    fi
fi

# Verify installation
if command -v opencode >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "OpenCode installed successfully"
        opencode --version 2>/dev/null || true
    fi
else
    eecho "Warning: OpenCode installation may not be complete. You may need to restart your shell."
fi

vecho "OpenCode setup complete!"
