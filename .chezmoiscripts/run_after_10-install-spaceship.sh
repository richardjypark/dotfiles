#!/bin/sh
set -e

# Verify zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
    echo "Error: zsh is not installed"
    exit 1
fi

echo "Setting up spaceship theme..."
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_ZSH="${SPACESHIP_ROOT}/spaceship.zsh"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# Ensure directories exist
mkdir -p "${HOME}/.oh-my-zsh/custom/themes"

# Force clone if not present
if [ ! -d "$SPACESHIP_ROOT" ]; then
    echo "Cloning spaceship-prompt..."
    git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "$SPACESHIP_ROOT"
fi

# Remove existing symlink if present
rm -f "$SPACESHIP_THEME"
sleep 1

if [ -f "$SPACESHIP_ZSH" ]; then
    echo "Creating spaceship theme symlink..."
    ln -sf "$SPACESHIP_ZSH" "$SPACESHIP_THEME"
    if [ -d "$SPACESHIP_ROOT" ]; then
        echo "Compiling theme files..."
        cd "$SPACESHIP_ROOT" || exit 1
        # Only try to compile if zsh is available
        if command -v zsh >/dev/null 2>&1; then
            zsh -c "zcompile spaceship.zsh"
            zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
        else
            echo "Warning: skipping compilation as zsh is not available"
        fi
    fi
else
    echo "Warning: Spaceship theme source not found at $SPACESHIP_ZSH"
    ls -la "$SPACESHIP_ROOT"
    exit 1
fi

echo "Spaceship theme setup complete!"