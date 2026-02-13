#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if state_exists "bun-setup"; then
    vecho "Bun setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Bun..."

# Ensure BUN_INSTALL is set for path checks
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
add_to_path "$BUN_INSTALL/bin"

# Fast exit if bun is already installed (but mark state)
if is_installed bun; then
    vecho "Bun is already installed: $(bun --version 2>/dev/null || echo 'installed')"
    mark_state "bun-setup"
    exit 0
fi

# Detect OS
OS="$(uname -s)"

install_via_homebrew() {
    if is_installed brew; then
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
    if install_via_homebrew; then
        vecho "Installed via Homebrew"
    elif install_via_script; then
        vecho "Installed via install script"
    else
        eecho "Error: Could not install Bun. Please install manually from https://bun.sh"
        exit 1
    fi
else
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
if is_installed bun; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Bun installed successfully"
        bun --version 2>/dev/null || true
    fi
    mark_state "bun-setup"
else
    eecho "Error: Bun installation failed. Leaving state unset so it can retry."
    exit 1
fi

vecho "Bun setup complete!"
