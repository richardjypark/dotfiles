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

# Colors for output (only used in verbose mode)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

vecho "${BLUE}Setting up tmux and tmux plugin manager...${NC}"

# Fast exit if tmux and TPM are already properly set up
TPM_DIR="$HOME/.tmux/plugins/tpm"
if command -v tmux &> /dev/null && [ -d "$TPM_DIR" ] && [ -f "$TPM_DIR/tpm" ]; then
    vecho "${GREEN}tmux and TPM are already installed and configured${NC}"
    exit 0
fi

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    eecho "Installing tmux..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            if [ "$VERBOSE" = "true" ]; then
                brew install tmux
            else
                brew install tmux >/dev/null 2>&1
            fi
        else
            eecho "Homebrew not found. Please install tmux manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y tmux
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y tmux
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm tmux
        else
            eecho "Unsupported Linux distribution. Please install tmux manually."
            exit 1
        fi
    else
        eecho "Unsupported OS. Please install tmux manually."
        exit 1
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

vecho "${GREEN}Tmux setup complete!${NC}" 