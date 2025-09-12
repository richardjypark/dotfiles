#!/bin/sh
# Base PATH
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Cursor PATH (cross-platform)
case "$(uname -s)" in
    Darwin*)    
        cursor_path="/Applications/Cursor.app/Contents/Resources/app/bin"
        # Homebrew OpenJDK 17 path (keg-only)
        jdk17_bin="/opt/homebrew/opt/openjdk@17/bin"
        [ -d "$jdk17_bin" ] && export PATH="$jdk17_bin:$PATH"
        ;;
    Linux*)     
        cursor_path="$HOME/.local/share/cursor/bin"
        ;;
esac
[ -d "$cursor_path" ] && export PATH="$PATH:$cursor_path"