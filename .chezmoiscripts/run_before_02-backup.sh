#!/bin/sh
set -e

BACKUP_DIR="$HOME/.config/chezmoi/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
for file in .zshrc .gitconfig .ssh/config; do
    [ -f "$HOME/$file" ] && cp -a "$HOME/$file" "$BACKUP_DIR/"
done
