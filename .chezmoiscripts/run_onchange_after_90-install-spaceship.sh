#!/bin/sh

set -e

# Install spaceship theme
echo "Setting up spaceship theme..."
SPACESHIP_ROOT="${HOME}/.oh-my-zsh/custom/themes/spaceship-prompt"
SPACESHIP_ZSH="${SPACESHIP_ROOT}/spaceship.zsh"
SPACESHIP_THEME="${HOME}/.oh-my-zsh/custom/themes/spaceship.zsh-theme"

# Ensure directories exist
mkdir -p "${HOME}/.oh-my-zsh/custom/themes"

# Create the symlink for spaceship theme with absolute path
echo "Creating symlink for spaceship theme..."
[ -e "$SPACESHIP_THEME" ] && rm -f "$SPACESHIP_THEME"
ln -sf "$SPACESHIP_ZSH" "$SPACESHIP_THEME"

# Compile theme files
echo "Compiling theme files..."
cd "$SPACESHIP_ROOT" || exit 1
zsh -c "zcompile spaceship.zsh"
zsh -c "for f in lib/*.zsh; do zcompile \$f; done"

# Install fzf
echo "Setting up fzf..."
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Install fzf binary and shell integration
if [ -d "$FZF_REPO_PATH" ]; then
    cd "$FZF_REPO_PATH"
    ./install --bin
    # Create symlink if needed
    [ ! -e "$FZF_TARGET" ] && ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"
    # Install shell integrations
    ./install --key-bindings --completion --no-bash --no-fish --no-update-rc
fi

echo "Dependencies installation complete!"
