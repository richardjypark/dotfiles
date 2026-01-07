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
# Check actual shell from passwd database (more reliable than $SHELL env var)
if [ "$(uname)" = "Darwin" ]; then
    # macOS: try dscl first, fall back to finger, then $SHELL
    CURRENT_SHELL=$(dscl . -read /Users/"$(whoami)" UserShell 2>/dev/null | awk '{print $2}')
    if [ -z "$CURRENT_SHELL" ]; then
        CURRENT_SHELL=$(finger "$(whoami)" 2>/dev/null | awk -F'Shell: ' '/Shell:/{print $2}')
    fi
    if [ -z "$CURRENT_SHELL" ]; then
        CURRENT_SHELL="$SHELL"
    fi
else
    # Linux uses getent
    CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
fi

if [ "$(basename "$CURRENT_SHELL")" = "zsh" ]; then
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
if [ "$(uname)" = "Darwin" ]; then
    # macOS: chsh prompts for password, no sudo needed
    chsh -s "$(command -v zsh)"
elif [ "$(id -u)" = 0 ]; then
    chsh -s "$(command -v zsh)" "$(whoami)"
else
    sudo chsh -s "$(command -v zsh)" "$(whoami)"
fi

vecho "Shell setup complete!"
