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
STATE_FILE="$STATE_DIR/claude-code-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Claude Code setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Claude Code..."

# Fast exit if claude is already installed and working (but mark state)
if command -v claude >/dev/null 2>&1; then
    # Verify it actually works (not just exists in PATH)
    if claude --version >/dev/null 2>&1; then
        vecho "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
        mkdir -p "$STATE_DIR"
        touch "$STATE_FILE"
        exit 0
    else
        vecho "Claude Code binary found but not working, reinstalling..."
    fi
fi

eecho "Installing Claude Code via official installer..."
if [ "$VERBOSE" = "true" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
else
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1
fi

# Verify installation
if command -v claude >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Claude Code installed successfully"
        claude --version 2>/dev/null || true
    fi
    # Mark setup as complete
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    vecho "Claude Code installation complete. You may need to restart your shell."
    # Still mark as complete since installation succeeded
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
fi

vecho "Claude Code setup complete!"
