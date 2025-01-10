#!/bin/sh
set -e

# Setup fzf
echo "Setting up fzf..."
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Verify that chezmoi has properly cloned the repository
if [ ! -d "$FZF_REPO_PATH" ] || [ ! -f "$FZF_REPO_PATH/install" ]; then
    echo "Error: fzf repository not properly initialized at $FZF_REPO_PATH"
    echo "This might indicate that chezmoi external file setup hasn't completed yet."
    echo "Try running 'chezmoi apply --refresh-externals' first."
    exit 1
fi

cd "$FZF_REPO_PATH" || exit 1

# Install binary
./install --bin

# Create symlink if needed
if [ ! -e "$FZF_TARGET" ]; then
    ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"
fi

# Install shell integrations
./install --key-bindings --completion --no-bash --no-fish --no-update-rc

# Verify installation
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf installation failed"
    exit 1
fi

FZF_VERSION=$(fzf --version)
echo "fzf setup complete! Version: $FZF_VERSION"
