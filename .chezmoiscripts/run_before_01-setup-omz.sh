#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() { 
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

vecho "Setting up Oh My Zsh structure..."

# Fast exit if directories already exist with proper permissions
if [ -d "${HOME}/.oh-my-zsh/custom/themes" ] && [ -d "${HOME}/.oh-my-zsh/custom/plugins" ]; then
    vecho "Oh My Zsh directory structure already exists"
    exit 0
fi

mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"

# Ensure proper permissions
chmod 755 "${HOME}/.oh-my-zsh/custom" 2>/dev/null || true
chmod 755 "${HOME}/.oh-my-zsh/custom/themes"
chmod 755 "${HOME}/.oh-my-zsh/custom/plugins"

vecho "Oh My Zsh directory structure created"
