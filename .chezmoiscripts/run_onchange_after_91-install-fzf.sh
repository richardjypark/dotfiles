#!/bin/sh

set -e

# Constants
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Install fzf binary
echo "Installing fzf..."
cd "$FZF_REPO_PATH"
if [ ! -f "$FZF_TARGET" ]; then
    ./install --bin
    # Create symlink if needed
    if [ ! -e "$FZF_TARGET" ]; then
        ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"
    fi
fi

# Install shell integrations (without modifying rc files)
./install --key-bindings --completion --no-bash --no-fish --no-update-rc
