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

vecho "Setting up uv (Python package manager)..."

UV_DIR="$HOME/.local/bin"

# Fast exit if uv is already installed
if command -v uv >/dev/null 2>&1; then
    vecho "uv is already installed: $(uv --version)"
    exit 0
fi

# Ensure .local/bin exists
mkdir -p "$UV_DIR"

# Install uv using the official installer
eecho "Installing uv..."
if [ "$VERBOSE" = "true" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi

# Verify installation
if command -v uv >/dev/null 2>&1 || [ -x "$UV_DIR/uv" ]; then
    if [ "$VERBOSE" = "true" ]; then
        echo "uv installed successfully: $(uv --version 2>/dev/null || $UV_DIR/uv --version)"
    fi
else
    eecho "Warning: uv installation may have failed. Check manually."
fi

vecho "uv setup complete!"
