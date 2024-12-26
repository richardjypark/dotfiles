#!/bin/sh

set -e

# Setup fzf
echo "Setting up fzf..."
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Wait briefly for files to be available
sleep 1

# Install fzf binary and shell integration
if [ -d "$FZF_REPO_PATH" ]; then
    cd "$FZF_REPO_PATH" || exit 1

    # Install binary
    ./install --bin

    # Create symlink if needed
    if [ ! -e "$FZF_TARGET" ]; then
        ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"
    fi

    # Install shell integrations
    ./install --key-bindings --completion --no-bash --no-fish --no-update-rc
else
    echo "Warning: fzf repository not found at $FZF_REPO_PATH"
    ls -la "$HOME/.local/share"
    exit 1
fi

echo "fzf setup complete!"
