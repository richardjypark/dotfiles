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
STATE_FILE="$STATE_DIR/opencode-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "OpenCode setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up OpenCode..."

# Fast exit if opencode is already installed and working (but mark state)
if command -v opencode >/dev/null 2>&1; then
    # Verify it actually works (not just exists in PATH)
    if opencode --version >/dev/null 2>&1; then
        vecho "OpenCode is already installed: $(opencode --version 2>/dev/null || echo 'installed')"
        mkdir -p "$STATE_DIR"
        touch "$STATE_FILE"
        exit 0
    else
        vecho "OpenCode binary found but not working, reinstalling..."
    fi
fi

# Install via curl (official method from https://opencode.ai/)
eecho "Installing OpenCode..."
if [ "$VERBOSE" = "true" ]; then
    curl -fsSL https://opencode.ai/install | bash
else
    curl -fsSL https://opencode.ai/install | bash >/dev/null 2>&1
fi

# Verify installation
if command -v opencode >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "OpenCode installed successfully"
        opencode --version 2>/dev/null || true
    fi
    # Mark setup as complete
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    vecho "OpenCode installation complete. You may need to restart your shell."
    # Still mark as complete since installation succeeded
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
fi

vecho "OpenCode setup complete!"
