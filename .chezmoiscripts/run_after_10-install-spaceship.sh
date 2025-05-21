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

# Only compile theme files if not running from chezmoi apply
if [ -z "$CHEZMOI" ] && command -v zsh >/dev/null 2>&1; then
    cd "$SPACESHIP_ROOT" || exit 1
    
    # Remove any existing .zwc files first to ensure clean compilation
    find "$SPACESHIP_ROOT" -name "*.zwc" -delete
    
    # Compile files
    zsh -c "zcompile spaceship.zsh"
    zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
elif command -v zsh >/dev/null 2>&1; then
    # When chezmoi is running this script, clean up and compile theme files
    find "$SPACESHIP_ROOT" -name "*.zwc" -delete
    cd "$SPACESHIP_ROOT" || exit 1
    zsh -c "zcompile spaceship.zsh"
    zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
else
    echo "Warning: zsh not available for compilation"
fi

echo "Spaceship theme setup complete!"
