#!/bin/sh

set -e

# Setup spaceship theme
echo "Setting up spaceship theme..."
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_ZSH="${SPACESHIP_ROOT}/spaceship.zsh"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# Clean up any existing theme files
rm -f "$SPACESHIP_THEME"

# Wait briefly for files to be available
sleep 1

# Create the symlink if source exists
if [ -f "$SPACESHIP_ZSH" ]; then
    echo "Creating spaceship theme symlink..."
    ln -sf "$SPACESHIP_ZSH" "$SPACESHIP_THEME"

    if [ -d "$SPACESHIP_ROOT" ]; then
        echo "Compiling theme files..."
        cd "$SPACESHIP_ROOT" || exit 1
        zsh -c "zcompile spaceship.zsh"
        zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
    fi
else
    echo "Warning: Spaceship theme source not found at $SPACESHIP_ZSH"
    ls -la "$SPACESHIP_ROOT"
    exit 1
fi

echo "Spaceship theme setup complete!"
