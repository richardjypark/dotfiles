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

vecho "Setting up Claude Code..."

# Fast exit if claude is already installed and working
if command -v claude >/dev/null 2>&1; then
    # Verify it actually works (not just exists in PATH)
    if claude --version >/dev/null 2>&1; then
        vecho "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
        exit 0
    else
        vecho "Claude Code binary found but not working, reinstalling..."
    fi
fi

# Check if npm is available (preferred method)
if command -v npm >/dev/null 2>&1; then
    eecho "Installing Claude Code via npm..."
    if [ "$VERBOSE" = "true" ]; then
        npm install -g @anthropic-ai/claude-code
    else
        npm install -g @anthropic-ai/claude-code >/dev/null 2>&1
    fi
else
    # Fallback: Try to load NVM and use npm from there
    NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
        if command -v npm >/dev/null 2>&1; then
            eecho "Installing Claude Code via npm (via NVM)..."
            if [ "$VERBOSE" = "true" ]; then
                npm install -g @anthropic-ai/claude-code
            else
                npm install -g @anthropic-ai/claude-code >/dev/null 2>&1
            fi
        else
            eecho "Warning: npm not available. Please install Node.js first, then run: npm install -g @anthropic-ai/claude-code"
            exit 0
        fi
    else
        eecho "Warning: npm not available. Please install Node.js first, then run: npm install -g @anthropic-ai/claude-code"
        exit 0
    fi
fi

# Verify installation
if command -v claude >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Claude Code installed successfully"
        claude --version 2>/dev/null || true
    fi
else
    vecho "Claude Code installation complete. You may need to restart your shell."
fi

vecho "Claude Code setup complete!"
