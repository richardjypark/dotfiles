#!/bin/sh

set -e  # Exit on error

# Constants
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# Create the symlink for spaceship theme
echo "Creating symlink for spaceship theme..."
[ -e "$SPACESHIP_THEME" ] && rm -f "$SPACESHIP_THEME"
ln -s "${SPACESHIP_ROOT}/spaceship.zsh" "$SPACESHIP_THEME"

# Compile theme files
echo "Compiling theme files..."
cd "$SPACESHIP_ROOT" || exit 1
zsh -c "zcompile spaceship.zsh"
zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
