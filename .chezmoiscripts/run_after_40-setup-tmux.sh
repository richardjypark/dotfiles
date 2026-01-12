#!/bin/bash

set -eufo pipefail

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "$@"
    fi
}
eecho() { echo -e "$@"; }

# State tracking
STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"
STATE_FILE="$STATE_DIR/tmux-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "tmux setup already completed (state tracked)"
    exit 0
fi

# Colors for output (only used in verbose mode)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

vecho "${BLUE}Setting up tmux and tmux plugin manager...${NC}"

# Fast exit if tmux and TPM are already properly set up (but mark state)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if command -v tmux &> /dev/null && [ -d "$TPM_DIR" ] && [ -f "$TPM_DIR/tpm" ]; then
    vecho "${GREEN}tmux and TPM are already installed and configured${NC}"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

# Helper function to run commands with sudo if needed (non-interactively)
run_privileged() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif sudo -n true 2>/dev/null; then
        sudo "$@"
    else
        return 1
    fi
}

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    TMUX_INSTALLED=false
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            eecho "Installing tmux via Homebrew..."
            if [ "$VERBOSE" = "true" ]; then
                brew install tmux && TMUX_INSTALLED=true
            else
                brew install tmux >/dev/null 2>&1 && TMUX_INSTALLED=true
            fi
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check if we can use sudo
        CAN_SUDO=false
        if [ "$(id -u)" = 0 ]; then
            CAN_SUDO=true
        elif sudo -n true 2>/dev/null; then
            CAN_SUDO=true
        fi

        if [ "$CAN_SUDO" = "true" ]; then
            eecho "Installing tmux..."
            if command -v apt-get &> /dev/null; then
                run_privileged apt-get update -qq && run_privileged apt-get install -y -qq tmux && TMUX_INSTALLED=true
            elif command -v dnf &> /dev/null; then
                run_privileged dnf install -y -q tmux && TMUX_INSTALLED=true
            elif command -v yum &> /dev/null; then
                run_privileged yum install -y -q tmux && TMUX_INSTALLED=true
            elif command -v pacman &> /dev/null; then
                run_privileged pacman -S --noconfirm --quiet tmux && TMUX_INSTALLED=true
            elif command -v zypper &> /dev/null; then
                run_privileged zypper install -y -q tmux && TMUX_INSTALLED=true
            elif command -v apk &> /dev/null; then
                run_privileged apk add --quiet tmux && TMUX_INSTALLED=true
            fi
        fi
    fi

    if [ "$TMUX_INSTALLED" = "false" ]; then
        eecho "Note: tmux not installed (requires sudo or manual install)"
        eecho "Install manually: sudo apt-get install tmux"
        # Continue to set up TPM anyway for when tmux becomes available
    fi
fi

# Install Tmux Plugin Manager if not already installed
if [ ! -d "$TPM_DIR" ]; then
    vecho "Installing Tmux Plugin Manager..."
    if [ "$VERBOSE" = "true" ]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    else
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null 2>&1
    fi
else
    vecho "TPM already installed, skipping git clone"
fi

# Install plugins automatically (only if TPM binary exists)
if [ -f "$TPM_DIR/bin/install_plugins" ]; then
    vecho "Installing tmux plugins..."
    if [ "$VERBOSE" = "true" ]; then
        "$TPM_DIR/bin/install_plugins"
    else
        "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1
    fi
else
    vecho "TPM install script not found, skipping plugin installation"
fi

# Mark setup as complete
mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

vecho "${GREEN}Tmux setup complete!${NC}"
