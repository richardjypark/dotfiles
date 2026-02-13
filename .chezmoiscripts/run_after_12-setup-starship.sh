#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if state_exists "starship-setup"; then
    vecho "Starship setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Starship prompt..."

add_to_path "$HOME/.local/bin"

# Fast exit if starship is already installed and working (but mark state)
if is_installed starship; then
    vecho "Starship is already installed: $(starship --version 2>/dev/null || echo 'installed')"
    mark_state "starship-setup"
    exit 0
fi

# Detect OS and install
case "$(uname -s)" in
    Darwin)
        if is_installed brew; then
            eecho "Installing Starship via Homebrew..."
            if [ "$VERBOSE" = "true" ]; then
                brew install starship
            else
                brew install starship --quiet 2>/dev/null || brew install starship
            fi
        else
            if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
                eecho "Refusing to run remote installer without explicit trust."
                eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow starship.rs/install.sh."
                exit 1
            fi
            eecho "Installing Starship via official installer (Homebrew not found)..."
            if [ "$VERBOSE" = "true" ]; then
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
            else
                curl -sS https://starship.rs/install.sh | sh -s -- --yes >/dev/null 2>&1
            fi
        fi
        ;;
    Linux)
        if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
            eecho "Refusing to run remote installer without explicit trust."
            eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow starship.rs/install.sh."
            exit 1
        fi
        # Use user-local bin if sudo is not available
        STARSHIP_BIN_DIR="/usr/local/bin"
        if ! is_installed sudo || ! sudo -n true 2>/dev/null; then
            STARSHIP_BIN_DIR="$HOME/.local/bin"
            mkdir -p "$STARSHIP_BIN_DIR"
        fi
        eecho "Installing Starship via official installer..."
        if [ "$VERBOSE" = "true" ]; then
            curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$STARSHIP_BIN_DIR"
        else
            curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$STARSHIP_BIN_DIR" >/dev/null 2>&1
        fi
        ;;
    *)
        eecho "Unsupported OS for Starship installation: $(uname -s)"
        exit 1
        ;;
esac

# Verify installation
if is_installed starship; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Starship installed successfully"
        starship --version 2>/dev/null || true
    fi
    mark_state "starship-setup"
else
    eecho "Error: Starship installation failed. Leaving state unset so it can retry."
    exit 1
fi

vecho "Starship setup complete!"
