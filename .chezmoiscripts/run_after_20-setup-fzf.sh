#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() { 
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}
eecho() { echo "$@"; }

# Setup fzf
vecho "Setting up fzf..."
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"

# Check if fzf needs reinstalling (version mismatch or missing)
NEEDS_INSTALL=false
if ! command -v fzf >/dev/null 2>&1 || [ ! -f "$FZF_TARGET" ]; then
    NEEDS_INSTALL=true
elif [ -f "$FZF_REPO_PATH/install" ]; then
    # Extract version from the install script (format: version=X.Y.Z)
    REPO_VERSION=$(grep '^version=' "$FZF_REPO_PATH/install" 2>/dev/null | head -1 | cut -d= -f2)
    INSTALLED_VERSION=$(fzf --version 2>/dev/null | awk '{print $1}')
    if [ -n "$REPO_VERSION" ] && [ "$REPO_VERSION" != "$INSTALLED_VERSION" ]; then
        vecho "Version mismatch: repo=$REPO_VERSION installed=$INSTALLED_VERSION"
        NEEDS_INSTALL=true
    fi
fi

if [ "$NEEDS_INSTALL" = "false" ]; then
    vecho "fzf is already installed and configured"
    exit 0
fi

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Verify that chezmoi has properly cloned the repository
if [ ! -d "$FZF_REPO_PATH" ] || [ ! -f "$FZF_REPO_PATH/install" ]; then
    eecho "Error: fzf repository not properly initialized at $FZF_REPO_PATH"
    eecho "This might indicate that chezmoi external file setup hasn't completed yet."
    eecho "Try running 'chezmoi apply --refresh-externals' first."
    exit 1
fi

cd "$FZF_REPO_PATH" || exit 1

# Install binary (suppress output unless verbose)
if [ "$VERBOSE" = "true" ]; then
    ./install --bin
else
    ./install --bin >/dev/null 2>&1
fi

# Create or update symlink
rm -f "$FZF_TARGET"
ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"

# Shell integrations are loaded directly from $FZF_BASE/shell/ in fzf.sh
vecho "fzf shell integrations loaded from repository files"

# Verify installation
if ! command -v fzf >/dev/null 2>&1; then
    eecho "Error: fzf installation failed"
    exit 1
fi

if [ "$VERBOSE" = "true" ]; then
    FZF_VERSION=$(fzf --version)
    vecho "fzf setup complete! Version: $FZF_VERSION"
fi
