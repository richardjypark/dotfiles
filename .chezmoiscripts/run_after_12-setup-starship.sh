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
STATE_FILE="$STATE_DIR/starship-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Starship setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Starship prompt..."

# Fast exit if starship is already installed and working (but mark state)
if command -v starship >/dev/null 2>&1; then
    vecho "Starship is already installed: $(starship --version 2>/dev/null || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

# Detect OS and install
case "$(uname -s)" in
    Darwin)
        if command -v brew >/dev/null 2>&1; then
            eecho "Installing Starship via Homebrew..."
            if [ "$VERBOSE" = "true" ]; then
                brew install starship
            else
                brew install starship --quiet 2>/dev/null || brew install starship
            fi
        else
            eecho "Installing Starship via official installer (Homebrew not found)..."
            if [ "$VERBOSE" = "true" ]; then
                curl -sS https://starship.rs/install.sh | sh -s -- --yes
            else
                curl -sS https://starship.rs/install.sh | sh -s -- --yes >/dev/null 2>&1
            fi
        fi
        ;;
    Linux)
        # Use user-local bin if sudo is not available
        STARSHIP_BIN_DIR="/usr/local/bin"
        if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
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
if command -v starship >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Starship installed successfully"
        starship --version 2>/dev/null || true
    fi
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    eecho "Warning: Starship installation may have failed. Check your PATH."
    # Still mark as complete to avoid repeated attempts
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
fi

vecho "Starship setup complete!"
