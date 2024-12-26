#!/bin/sh

set -e

# Constants
REPO_URL="https://github.com/richardjypark/dotfiles.git"
CHEZMOI_BIN_DIR="$HOME/.local/bin"
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
BACKUP_DIR="$HOME/.local/share/chezmoi.backup.$(date +%Y%m%d_%H%M%S)"

# Function to output error messages
error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to output status messages
info() {
    echo "-> $1"
}

# Check for required commands
check_requirements() {
    if ! command -v git >/dev/null 2>&1; then
        error "Git is required but not installed"
    fi
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        error "Either curl or wget is required for installation"
    fi
}

# Install chezmoi if not present
install_chezmoi() {
    if ! command -v chezmoi >/dev/null 2>&1; then
        info "Installing chezmoi..."
        mkdir -p "$CHEZMOI_BIN_DIR"

        if command -v curl >/dev/null 2>&1; then
            sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$CHEZMOI_BIN_DIR"
        else
            sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$CHEZMOI_BIN_DIR"
        fi

        export PATH="$PATH:$CHEZMOI_BIN_DIR"
    else
        info "Chezmoi already installed"
    fi
}

# Backup existing chezmoi configuration
backup_existing_config() {
    if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
        info "Backing up existing chezmoi configuration..."
        mkdir -p "$BACKUP_DIR"

        # Copy files maintaining relative structure but in a flat backup directory
        cd "$CHEZMOI_SOURCE_DIR"
        find . -type f -exec cp --parents {} "$BACKUP_DIR" \; 2>/dev/null || \
        find . -type f -exec sh -c 'mkdir -p "$2/$(dirname "$1")" && cp "$1" "$2/$(dirname "$1")/"' _ {} "$BACKUP_DIR" \;

        info "Backup created at: $BACKUP_DIR"

        # Remove existing source directory
        rm -rf "$CHEZMOI_SOURCE_DIR"
    fi
}

# Initialize or update chezmoi repository
setup_chezmoi_repo() {
    info "Cloning dotfiles repository..."
    git clone --depth=1 "$REPO_URL" "$CHEZMOI_SOURCE_DIR"

    cd "$CHEZMOI_SOURCE_DIR"
    git checkout -b master 2>/dev/null || true
    git branch --set-upstream-to=origin/master master || \
        git branch --set-upstream-to=origin/main master

    info "Initializing chezmoi with source directory..."
    chezmoi init --source="$CHEZMOI_SOURCE_DIR"
}

# Apply chezmoi configuration
apply_chezmoi() {
    info "Applying dotfiles..."
    chezmoi apply --refresh-externals
}

# Main installation function
main() {
    info "Starting dotfiles installation..."

    check_requirements
    install_chezmoi
    backup_existing_config
    setup_chezmoi_repo
    apply_chezmoi

    info "Installation complete! Please restart your shell."
    info "Your previous configuration has been backed up to: $BACKUP_DIR"
}

# Run main function
main "$@"
