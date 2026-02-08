#!/usr/bin/env bash
set -euo pipefail

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
TRUST_ON_FIRST_USE_INSTALLERS=${TRUST_ON_FIRST_USE_INSTALLERS:-0}
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

# Ensure ~/.local/bin is in PATH (where the installer places the binary)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

vecho "Setting up Claude Code..."

# Fast exit if claude is already installed and working (but mark state)
if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
    vecho "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

eecho "Installing Claude Code via official installer..."
if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
    eecho "Refusing to run remote installer without explicit trust."
    eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow claude.ai/install.sh."
    exit 1
fi
if [ "$VERBOSE" = "true" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
else
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1
fi

# Verify installation
if command -v claude >/dev/null 2>&1 && claude --version >/dev/null 2>&1; then
    eecho "Claude Code installed successfully: $(claude --version 2>/dev/null)"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    eecho "Error: Claude Code installation failed. Leaving state unset so it can retry."
    exit 1
fi
