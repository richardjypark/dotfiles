#!/bin/sh
set -e

# Exit if not running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Update package list
apt-get update

# Install essential packages
apt-get install -y \
    zsh \
    git \
    curl

# Create necessary directories
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
mkdir -p "$HOME/.oh-my-zsh/custom/plugins"

# Add .local/bin to PATH if not already there
if ! grep -q '$HOME/.local/bin' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
fi

# Source the profile to get the updated PATH
. "$HOME/.profile"

# Install chezmoi if not present
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Set zsh as default shell for the current user
chsh -s "$(which zsh)" "$(whoami)"

echo "Prerequisites installation complete!"