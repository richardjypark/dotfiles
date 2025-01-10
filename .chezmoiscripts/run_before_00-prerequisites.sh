#!/bin/sh
set -e

echo "Checking prerequisites..."

# Function to check if a package is installed
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Only attempt package installations if we have sudo rights
if [ "$(id -u)" = 0 ] || is_installed sudo; then
    # Check if essential packages are missing
    MISSING_PACKAGES=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done

    # Only run apt-get if we actually need packages
    if [ -n "$MISSING_PACKAGES" ]; then
        echo "Installing missing packages:$MISSING_PACKAGES"
        if [ "$(id -u)" = 0 ]; then
            apt-get update
            echo "$MISSING_PACKAGES" | xargs -n1 | xargs -P4 apt-get install -y
        else
            sudo apt-get update
            echo "$MISSING_PACKAGES" | xargs -n1 | sudo xargs -P4 apt-get install -y
        fi
    else
        echo "All required packages are already installed"
    fi
else
    echo "Note: Skipping package installation (no root/sudo access)"
fi

# Create directories if they don't exist (no root needed)
for dir in "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.oh-my-zsh/custom/themes" "$HOME/.oh-my-zsh/custom/plugins"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Created directory: $dir"
    fi
done

# Add .local/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    if ! grep -q '$HOME/.local/bin' "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.profile"
        echo "Added .local/bin to PATH"
    fi
fi

# Install chezmoi only if not present
if ! is_installed chezmoi; then
    echo "Installing chezmoi..."
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "chezmoi is already installed"
fi

# Only change shell if not already zsh
if [ "$SHELL" != "$(which zsh)" ] && is_installed zsh; then
    echo "Changing default shell to zsh..."
    if [ "$(id -u)" = 0 ]; then
        chsh -s "$(which zsh)" "$(whoami)"
    else
        sudo chsh -s "$(which zsh)" "$(whoami)"
    fi
else
    echo "Shell is already set to zsh"
fi

echo "Prerequisites check complete!"
