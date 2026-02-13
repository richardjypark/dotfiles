#!/usr/bin/env bash
set -euo pipefail

HELPER_PATH="$HOME/.local/lib/chezmoi-helpers.sh"
if [ -f "$HELPER_PATH" ]; then
    . "$HELPER_PATH"
else
    CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
    if [ -n "$CHEZMOI_SOURCE_DIR" ] && [ -f "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" ]; then
        . "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh"
    else
        echo "Error: could not locate chezmoi helper library." >&2
        echo "Expected either $HELPER_PATH or $CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" >&2
        exit 1
    fi
fi

# State tracking with inline fallback validation
if state_exists "omz-setup"; then
    if [ -d "${HOME}/.oh-my-zsh/custom/themes" ] && [ -d "${HOME}/.oh-my-zsh/custom/plugins" ]; then
        vecho "Oh My Zsh directory structure already exists"
        exit 0
    fi
fi

vecho "Setting up Oh My Zsh structure..."

# Fast exit if directories already exist with proper permissions
if [ -d "${HOME}/.oh-my-zsh/custom/themes" ] && [ -d "${HOME}/.oh-my-zsh/custom/plugins" ]; then
    vecho "Oh My Zsh directory structure already exists"
    mark_state "omz-setup"
    exit 0
fi

mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"

# Ensure proper permissions
chmod 755 "${HOME}/.oh-my-zsh/custom" 2>/dev/null || true
chmod 755 "${HOME}/.oh-my-zsh/custom/themes"
chmod 755 "${HOME}/.oh-my-zsh/custom/plugins"

mark_state "omz-setup"
vecho "Oh My Zsh directory structure created"
