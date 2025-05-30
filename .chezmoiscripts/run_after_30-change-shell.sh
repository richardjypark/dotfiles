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

# Fast exit if shell is already zsh
if [ "$SHELL" = "$(command -v zsh 2>/dev/null)" ]; then
    vecho "Shell is already set to zsh"
    exit 0
fi

# Check if zsh is available
if ! command -v zsh >/dev/null 2>&1; then
    vecho "Warning: zsh not found. Skipping shell change."
    exit 0
fi

# Change shell to zsh
eecho "Changing default shell to zsh..."
if [ "$(id -u)" = 0 ]; then
    chsh -s "$(command -v zsh)" "$(whoami)"
else
    sudo chsh -s "$(command -v zsh)" "$(whoami)"
fi

vecho "Shell setup complete!"
