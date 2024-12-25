#!/bin/sh

# exit on error, undefined variables, and pipe failures
set -euo pipefail

# detect OS and architecture
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        Linux) echo "linux" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "unknown" ;;
    esac
}

# function to handle errors
error() {
    echo "Error: $1" >&2
    exit 1
}

# Check for required commands
check_requirements() {
    if ! command -v curl >/dev/null && ! command -v wget >/dev/null; then
        error "Either curl or wget is required for installation"
    fi
}

# Clean existing chezmoi installation
clean_existing_chezmoi() {
    echo "Checking for existing chezmoi configuration..."
    
    # Check for existing chezmoi config directory
    if [ -d "$HOME/.config/chezmoi" ]; then
        echo "Found existing chezmoi configuration"
        echo "Backing up and removing existing configuration..."
        backup_dir="$HOME/.config/chezmoi.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/.config/chezmoi" "$backup_dir"
        echo "Backed up existing configuration to $backup_dir"
    fi

    # Check for existing source directory
    if [ -d "$HOME/.local/share/chezmoi" ]; then
        echo "Found existing chezmoi source directory"
        echo "Backing up and removing existing source..."
        backup_dir="$HOME/.local/share/chezmoi.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/.local/share/chezmoi" "$backup_dir"
        echo "Backed up existing source to $backup_dir"
    fi
}

# Install chezmoi if not present
install_chezmoi() {
    if ! command -v chezmoi >/dev/null; then
        echo "Installing chezmoi..."
        bin_dir="$HOME/.local/bin"
        chezmoi="$bin_dir/chezmoi"
        
        # Create bin directory if it doesn't exist
        mkdir -p "$bin_dir"
        
        if command -v curl >/dev/null; then
            sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
        else
            sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
        fi
        
        # Add to PATH if not already there
        if ! echo "$PATH" | grep -q "$bin_dir"; then
            export PATH="$PATH:$bin_dir"
        fi
    else
        chezmoi="chezmoi"
    fi
}

# Reset chezmoi state
reset_chezmoi() {
    if command -v chezmoi >/dev/null; then
        echo "Purging existing chezmoi state..."
        chezmoi purge --force
    fi
}

# Main installation function
main() {
    # Get script directory
    script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
    
    # Detect system information
    OS=$(detect_os)
    ARCH=$(detect_arch)
    
    echo "Detected OS: $OS"
    echo "Detected architecture: $ARCH"
    
    # Check requirements
    check_requirements
    
    # Clean existing chezmoi setup
    clean_existing_chezmoi
    
    # Install chezmoi if needed
    install_chezmoi
    
    # Reset any existing state
    reset_chezmoi
    
    echo "Initializing fresh dotfiles..."
    
    # Initialize chezmoi with the current directory as source
    if [ "$OS" = "windows" ]; then
        # Windows-specific configuration
        "$chezmoi" init --apply "--source=$script_dir" --verbose
    else
        # Unix-like systems configuration
        "$chezmoi" init --apply "--source=$script_dir"
    fi
    
    echo "Installation complete! Please restart your shell."
}

# Run main function
main "$@"
