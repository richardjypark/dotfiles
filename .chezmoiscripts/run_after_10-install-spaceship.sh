#!/bin/sh
set -e

echo "Setting up spaceship theme..."
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_ZSH="${SPACESHIP_ROOT}/spaceship.zsh"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# Ensure parent directories exist with proper permissions
mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
chmod 755 "${HOME}/.oh-my-zsh/custom/themes"

# Remove existing spaceship directory and theme if they exist
rm -rf "$SPACESHIP_ROOT"
rm -f "$SPACESHIP_THEME"

# Clone the repository
echo "Cloning spaceship-prompt..."
git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "$SPACESHIP_ROOT"

# Verify the clone was successful
if [ ! -d "$SPACESHIP_ROOT" ]; then
    echo "Error: Failed to clone spaceship-prompt repository"
    exit 1
fi

# Verify spaceship.zsh exists
if [ ! -f "$SPACESHIP_ZSH" ]; then
    echo "Error: spaceship.zsh not found at $SPACESHIP_ZSH"
    ls -la "$SPACESHIP_ROOT"
    exit 1
fi

echo "Creating spaceship theme symlink..."
ln -sf "$SPACESHIP_ZSH" "$SPACESHIP_THEME"

echo "Compiling theme files..."
cd "$SPACESHIP_ROOT" || exit 1
if command -v zsh >/dev/null 2>&1; then
    zsh -c "zcompile spaceship.zsh"
    zsh -c "for f in lib/*.zsh; do zcompile \$f; done"
else
    echo "Warning: zsh not available for compilation"
fi

echo "Spaceship theme setup complete!"