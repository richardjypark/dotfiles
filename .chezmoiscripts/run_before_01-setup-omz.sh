#!/usr/bin/env bash
set -euo pipefail

CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
if [ -z "$CHEZMOI_SOURCE_DIR" ]; then
    CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
fi
# shellcheck disable=SC1090
. "$CHEZMOI_SOURCE_DIR/scripts/lib/load-helpers.sh"

if ! command -v should_skip_state >/dev/null 2>&1; then
    should_skip_state() {
        local state_name="$1"
        if state_exists "$state_name" && ! is_force_update; then
            return 0
        fi
        return 1
    }
fi

# State tracking with inline fallback validation
if should_skip_state "omz-setup"; then
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
