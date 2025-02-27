#!/bin/bash

set -eufo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up tmux and tmux plugin manager...${NC}"

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo -e "${BLUE}Installing tmux...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install tmux
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y tmux
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y tmux
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm tmux
        else
            echo "Unsupported Linux distribution. Please install tmux manually."
            exit 1
        fi
    else
        echo "Unsupported OS. Please install tmux manually."
        exit 1
    fi
fi

# Install Tmux Plugin Manager if not already installed
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo -e "${BLUE}Installing Tmux Plugin Manager...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    echo -e "${BLUE}Updating Tmux Plugin Manager...${NC}"
    (cd "$TPM_DIR" && git pull)
fi

# Install plugins automatically
echo -e "${BLUE}Installing tmux plugins...${NC}"
"$TPM_DIR/bin/install_plugins"

echo -e "${GREEN}Tmux setup complete!${NC}" 