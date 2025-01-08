#!/bin/sh
#
# Configures the spaceship theme symlink and compilation
# This script runs after the external archive is downloaded

set -e # Exit on any error

# Define key paths
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_ZSH="${SPACESHIP_ROOT}/spaceship.zsh"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

echo "Setting up spaceship theme symlink..."

# Create symlink for the theme
ln -sf "$SPACESHIP_ZSH" "$SPACESHIP_THEME"

echo "Compiling theme files..."

# Compile the theme files if zsh is available
if command -v zsh >/dev/null 2>&1; then
    cd "$SPACESHIP_ROOT" || exit 1
    zsh -c "zcompile spaceship.zsh"
    zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
else
    echo "Warning: zsh not available for compilation"
fi

echo "Spaceship theme setup complete!"
