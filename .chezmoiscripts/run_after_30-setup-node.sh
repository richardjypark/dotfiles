#!/bin/sh
set -e

# Setup Node.js via NVM
echo "Setting up Node.js via NVM..."
NVM_DIR="$HOME/.nvm"
DEFAULT_NODE_VERSION="lts/*"

# Verify that chezmoi has properly cloned the repository
if [ ! -d "$NVM_DIR" ] || [ ! -f "$NVM_DIR/nvm.sh" ]; then
    echo "Error: NVM repository not properly initialized at $NVM_DIR"
    echo "This might indicate that chezmoi external file setup hasn't completed yet."
    echo "Try running 'chezmoi apply --refresh-externals' first."
    exit 1
fi

# Load NVM
. "$NVM_DIR/nvm.sh"

# Install default Node version if not already installed
if ! nvm which "$DEFAULT_NODE_VERSION" >/dev/null 2>&1; then
    echo "Installing Node.js $DEFAULT_NODE_VERSION..."
    nvm install "$DEFAULT_NODE_VERSION"
    nvm alias default "$DEFAULT_NODE_VERSION"
fi

# Use the default version
nvm use default

# Install essential global packages
echo "Installing essential global npm packages..."
npm install -g npm@latest # Update npm itself
npm install -g yarn
npm install -g pnpm

# Verify installation
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
echo "Node.js setup complete!"
echo "Node.js version: $NODE_VERSION"
echo "npm version: $NPM_VERSION"

# Add helpful message about shell restart
echo "\nIMPORTANT: To use Node.js in your current session, either:"
echo "1. Restart your shell:    exec zsh"
echo "2. Or source NVM:         source ~/.nvm/nvm.sh"
