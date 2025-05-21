#!/bin/sh
# Spaceship theme configuration and compilation
# This file is loaded by .zshrc to ensure theme files are always compiled

# Define key paths
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"

# Only compile if the files exist and zsh is available
if [ -d "$SPACESHIP_ROOT" ] && command -v zsh >/dev/null 2>&1; then
    # Check if any .zsh file is newer than its compiled version
    NEED_COMPILE=0
    for f in "$SPACESHIP_ROOT/spaceship.zsh" "$SPACESHIP_ROOT"/lib/*.zsh; do
        if [ ! -f "${f}.zwc" ] || [ "$f" -nt "${f}.zwc" ]; then
            NEED_COMPILE=1
            break
        fi
    done
    
    # Only compile if needed (files are newer than compiled versions)
    if [ "$NEED_COMPILE" -eq 1 ]; then
        (
            cd "$SPACESHIP_ROOT" || return
            # Compile in the background to avoid slowing down shell startup
            zsh -c "zcompile spaceship.zsh" >/dev/null 2>&1
            zsh -c "for f in lib/*.zsh; do zcompile \$f; done" >/dev/null 2>&1
        ) &
    fi
fi 