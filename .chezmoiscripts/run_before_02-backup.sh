#!/bin/sh
set -e

echo "Creating backup of existing configurations..."

# Get OS type
OS_TYPE=$(uname -s)

# Define backup directory structure
BACKUP_BASE="$HOME/.dotfiles.backups"
LATEST_LINK="$BACKUP_BASE/latest"
BACKUP_DIR="$BACKUP_BASE/backup.$(date +%Y%m%d_%H%M%S)"

# Cleanup old backups - keep only last 3
cleanup_old_backups() {
    backup_count=$(find "$BACKUP_BASE" -maxdepth 1 -type d -name "backup.*" | wc -l)
    if [ "$backup_count" -gt 3 ]; then
        echo "Cleaning up old backups..."
        find "$BACKUP_BASE" -maxdepth 1 -type d -name "backup.*" | sort | head -n -3 | xargs rm -rf
    fi
}

# Create base backup directory if it doesn't exist
mkdir -p "$BACKUP_BASE"

# Function to backup a file/directory if it exists
backup_if_exists() {
    local path="$1"
    local name=$(basename "$path")

    # Skip if path doesn't exist
    [ ! -e "$path" ] && return 0

    # Check if we have a previous backup and if file has changed
    if [ -L "$LATEST_LINK" ] && [ -e "$LATEST_LINK/$name" ]; then
        if diff -rq "$path" "$LATEST_LINK/$name" >/dev/null 2>&1; then
            echo "Skipping unchanged $name..."
            return 0
        fi
    fi

    echo "Backing up $name..."
    mkdir -p "$BACKUP_DIR"
    case "$OS_TYPE" in
    Darwin*)
        cp -R "$path" "$BACKUP_DIR/" 2>/dev/null || {
            echo "Warning: Could not backup $name, continuing..."
            return 0
        }
        ;;
    Linux*)
        cp -a "$path" "$BACKUP_DIR/" 2>/dev/null || {
            echo "Warning: Could not backup $name, continuing..."
            return 0
        }
        ;;
    esac
}

# Check if chezmoi is installed and get managed files
if command -v chezmoi >/dev/null 2>&1; then
    echo "Chezmoi detected, backing up managed files..."
    CHEZMOI_MANAGED_FILES=$(chezmoi managed)
    echo "$CHEZMOI_MANAGED_FILES" | while IFS= read -r file; do
        [ -e "$file" ] && backup_if_exists "$file"
    done
else
    echo "First-time setup detected, backing up existing dotfiles..."
    backup_if_exists "$HOME/.zshrc"

    # OS-specific backups
    case "$OS_TYPE" in
    Darwin*)
        backup_if_exists "$HOME/.config"
        ;;
    Linux*)
        [ -d "$HOME/.config" ] && {
            for dir in shell git nvim; do
                backup_if_exists "$HOME/.config/$dir"
            done
        }
        ;;
    esac
fi

# Check if backup was created
if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "Backup created successfully at $BACKUP_DIR"

    # Update permissions
    if [ "$OS_TYPE" = "Darwin" ]; then
        chmod -R u+rw "$BACKUP_DIR"
    else
        chmod -R u+rw,go-w "$BACKUP_DIR"
    fi

    # Update latest symlink
    rm -f "$LATEST_LINK"
    ln -sf "$BACKUP_DIR" "$LATEST_LINK"

    # Cleanup old backups
    cleanup_old_backups
else
    # Remove empty backup directory if no files were backed up
    [ -d "$BACKUP_DIR" ] && rmdir "$BACKUP_DIR" 2>/dev/null || true
    echo "No files needed backup"
fi

exit 0
