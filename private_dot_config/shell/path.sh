#!/bin/sh
# PATH Management - Central location for all PATH modifications
# This file is loaded by ~/.zshrc for interactive shells

# Helper function to add paths without duplicates
# Usage: path_prepend /new/path
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;  # Already in PATH, skip
        *) export PATH="$1:$PATH" ;;
    esac
}

# Usage: path_append /new/path
path_append() {
    case ":$PATH:" in
        *":$1:"*) ;;  # Already in PATH, skip
        *) export PATH="$PATH:$1" ;;
    esac
}

# Base directories (highest priority first)
# Note: ~/.local/bin is already in PATH from ~/.zshenv for non-interactive shells
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"
path_prepend "/usr/local/bin"

# uv-managed Python (add latest installed version to PATH)
if [ -d "$HOME/.local/share/uv/python" ]; then
    # Find the most recent Python installation
    uv_python_bin=$(find "$HOME/.local/share/uv/python" -maxdepth 2 -type d -name "bin" 2>/dev/null | sort -V | tail -1)
    [ -n "$uv_python_bin" ] && path_prepend "$uv_python_bin"
fi

# Platform-specific paths
case "$(uname -s)" in
    Darwin*)
        # macOS-specific paths

        # Homebrew OpenJDK 17 path (keg-only)
        jdk17_bin="/opt/homebrew/opt/openjdk@17/bin"
        [ -d "$jdk17_bin" ] && path_prepend "$jdk17_bin"

        # Cursor IDE
        cursor_path="/Applications/Cursor.app/Contents/Resources/app/bin"
        [ -d "$cursor_path" ] && path_append "$cursor_path"
        ;;
    Linux*)
        # Linux-specific paths

        # Cursor IDE
        cursor_path="$HOME/.local/share/cursor/bin"
        [ -d "$cursor_path" ] && path_append "$cursor_path"
        ;;
esac

# Clean up helper functions
unset -f path_prepend path_append
