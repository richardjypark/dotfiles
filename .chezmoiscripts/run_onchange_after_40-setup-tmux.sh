#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if should_skip_state "tmux-setup"; then
    vecho "tmux setup already completed (state tracked)"
    exit 0
fi

# Colors for output (only used in verbose mode)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Local color-aware output wrappers
cvecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "$@"
    fi
}

cvecho "${BLUE}Setting up tmux and tmux plugin manager...${NC}"

# Fast exit if tmux and TPM are already properly set up (but mark state)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if is_installed tmux && [ -d "$TPM_DIR" ] && [ -f "$TPM_DIR/tpm" ]; then
    cvecho "${GREEN}tmux and TPM are already installed and configured${NC}"
    mark_state "tmux-setup"
    exit 0
fi

# Check if tmux is installed
if ! is_installed tmux; then
    TMUX_INSTALLED=false
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if is_installed brew; then
            eecho "Installing tmux via Homebrew..."
            if [ "$VERBOSE" = "true" ]; then
                brew install tmux && TMUX_INSTALLED=true
            else
                brew install tmux >/dev/null 2>&1 && TMUX_INSTALLED=true
            fi
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CAN_SUDO=false
        if [ "$(id -u)" = 0 ]; then
            CAN_SUDO=true
        elif ensure_sudo; then
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
    cvecho "Installing Tmux Plugin Manager..."
    if [ "$VERBOSE" = "true" ]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    else
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR" >/dev/null 2>&1
    fi
else
    cvecho "TPM already installed, skipping git clone"
fi

# Install plugins automatically (only if TPM binary exists)
if [ -f "$TPM_DIR/bin/install_plugins" ]; then
    cvecho "Installing tmux plugins..."
    if [ "$VERBOSE" = "true" ]; then
        "$TPM_DIR/bin/install_plugins"
    else
        "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1
    fi
else
    cvecho "TPM install script not found, skipping plugin installation"
fi

if is_installed tmux && [ -d "$TPM_DIR" ] && [ -f "$TPM_DIR/tpm" ]; then
    mark_state "tmux-setup"
else
    eecho "tmux setup incomplete; leaving state unset so setup can retry."
fi

cvecho "${GREEN}Tmux setup complete!${NC}"
