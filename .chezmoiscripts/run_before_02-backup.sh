#!/bin/sh
set -e

echo "Creating backup of existing configurations..."

# Get OS type
OS_TYPE=$(uname -s)

# Define backup directory with timestamp
BACKUP_DIR="$HOME/.dotfiles.backup.$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Function to backup a file/directory if it exists
backup_if_exists() {
    local path="$1"
    local name=$(basename "$path")
    if [ -e "$path" ]; then
        echo "Backing up $name..."
        case "$OS_TYPE" in
        Darwin*)
            # macOS: Use -R for recursive copy and preserve flags
            cp -R "$path" "$BACKUP_DIR/" 2>/dev/null || {
                echo "Warning: Could not backup $name, continuing..."
                return 0
            }
            ;;
        Linux*)
            # Linux: Use -a for archive mode (preserves permissions)
            cp -a "$path" "$BACKUP_DIR/" 2>/dev/null || {
                echo "Warning: Could not backup $name, continuing..."
                return 0
            }
            ;;
        *)
            echo "Warning: Unknown OS type $OS_TYPE, using basic copy..."
            cp -r "$path" "$BACKUP_DIR/" 2>/dev/null || {
                echo "Warning: Could not backup $name, continuing..."
                return 0
            }
            ;;
        esac
    fi
}

# OS-specific paths to backup
case "$OS_TYPE" in
Darwin*)
    # macOS-specific paths
    backup_if_exists "$HOME/Library/Application Support/Code/User/settings.json"
    backup_if_exists "$HOME/.config"
    ;;
Linux*)
    # Linux-specific paths
    backup_if_exists "$HOME/.config"
    backup_if_exists "$HOME/.local/share/applications"
    ;;
esac

# Common paths to backup for both OS types
backup_if_exists "$HOME/.zshrc"
backup_if_exists "$HOME/.oh-my-zsh"
backup_if_exists "$HOME/.nvm"
backup_if_exists "$HOME/.config/shell"
backup_if_exists "$HOME/.local/share/fzf"

# Check if backup was successful
if [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "Backup created successfully at $BACKUP_DIR"
    # Set appropriate permissions
    if [ "$OS_TYPE" = "Darwin" ]; then
        chmod -R u+rw "$BACKUP_DIR"
    else
        chmod -R u+rw,go-w "$BACKUP_DIR"
    fi
else
    # Remove empty backup directory if no files were backed up
    rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "No existing configurations needed backup"
fi

exit 0
