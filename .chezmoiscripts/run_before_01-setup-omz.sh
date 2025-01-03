#!/bin/sh
set -e

echo "Setting up Oh My Zsh structure..."
mkdir -p "${HOME}/.oh-my-zsh/custom/themes"
mkdir -p "${HOME}/.oh-my-zsh/custom/plugins"

# Ensure proper permissions
chmod 755 "${HOME}/.oh-my-zsh/custom"
chmod 755 "${HOME}/.oh-my-zsh/custom/themes"
chmod 755 "${HOME}/.oh-my-zsh/custom/plugins"

echo "Oh My Zsh directory structure created"
