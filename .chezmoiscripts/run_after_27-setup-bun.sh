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
STATE_FILE="$STATE_DIR/bun-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Bun setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Bun..."

# Ensure BUN_INSTALL is set for path checks
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$PATH"

# Fast exit if bun is already installed (but mark state)
if command -v bun >/dev/null 2>&1; then
    vecho "Bun is already installed: $(bun --version 2>/dev/null || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

# Detect OS
OS="$(uname -s)"

install_via_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eecho "Installing Bun via Homebrew..."
        if [ "$VERBOSE" = "true" ]; then
            brew install oven-sh/bun/bun
        else
            brew install oven-sh/bun/bun >/dev/null 2>&1
        fi
        return 0
    fi
    return 1
}

install_via_script() {
    # Use official Bun install script
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to run remote installer without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow bun.sh/install."
        return 1
    fi
    eecho "Installing Bun via official install script..."
    if [ "$VERBOSE" = "true" ]; then
        curl -fsSL https://bun.sh/install | bash
    else
        curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1
    fi
    return 0
}

# Try installation methods in order of preference
if [ "$OS" = "Darwin" ]; then
    # macOS: prefer Homebrew for easier updates
    if install_via_homebrew; then
        vecho "Installed via Homebrew"
    elif install_via_script; then
        vecho "Installed via install script"
    else
        eecho "Error: Could not install Bun. Please install manually from https://bun.sh"
        exit 1
    fi
else
    # Linux: use install script (Homebrew less common on servers)
    if install_via_script; then
        vecho "Installed via install script"
    elif install_via_homebrew; then
        vecho "Installed via Homebrew"
    else
        eecho "Error: Could not install Bun. Please install manually from https://bun.sh"
        exit 1
    fi
fi

# Verify installation
export PATH="$BUN_INSTALL/bin:$PATH"
if command -v bun >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Bun installed successfully"
        bun --version 2>/dev/null || true
    fi
    # Mark setup as complete
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    eecho "Error: Bun installation failed. Leaving state unset so it can retry."
    exit 1
fi

vecho "Bun setup complete!"
