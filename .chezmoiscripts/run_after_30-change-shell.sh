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
ZSH_PATH="$(command -v zsh)"

if [ "$(uname)" = "Darwin" ]; then
    # macOS: chsh prompts for password, no sudo needed
    chsh -s "$ZSH_PATH"
elif [ "$(id -u)" = 0 ]; then
    chsh -s "$ZSH_PATH" "$(whoami)"
else
    # Check if we can use sudo non-interactively
    if sudo -n true 2>/dev/null; then
        sudo chsh -s "$ZSH_PATH" "$(whoami)"
    else
        # Try chsh without sudo (some systems allow users to change their own shell)
        if chsh -s "$ZSH_PATH" 2>/dev/null; then
            vecho "Changed shell without sudo"
        else
            eecho "Note: Cannot change shell without sudo password."
            eecho "Run manually: sudo chsh -s $ZSH_PATH $(whoami)"
            exit 0
        fi
    fi
fi

vecho "Shell setup complete!"
