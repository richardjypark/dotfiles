#!/bin/sh

set -e

# Constants
REPO_URL="https://github.com/richardjypark/dotfiles.git"
CHEZMOI_BIN_DIR="$HOME/.local/bin"
CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"

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

# Initialize or update chezmoi repository
setup_chezmoi_repo() {
    if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
        info "Existing chezmoi source directory found"
        # Backup existing directory
        backup_dir="$CHEZMOI_SOURCE_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        info "Creating backup at $backup_dir"
        mv "$CHEZMOI_SOURCE_DIR" "$backup_dir"
    fi

    info "Cloning dotfiles repository..."
    git clone --depth=1 "$REPO_URL" "$CHEZMOI_SOURCE_DIR"

    # Setup git branch tracking
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
    # Force refresh of external files and apply changes
    chezmoi apply --refresh-externals
}

# Main installation function
main() {
    info "Starting dotfiles installation..."

    # Check requirements
    check_requirements

    # Install chezmoi if needed
    install_chezmoi

    # Setup or update repository
    setup_chezmoi_repo

    # Apply configuration
    apply_chezmoi

    info "Installation complete! Please restart your shell."
}

# Run main function
main "$@"
