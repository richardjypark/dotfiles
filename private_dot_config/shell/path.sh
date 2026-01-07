#!/bin/sh
# Base PATH
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# uv-managed Python (add latest installed version to PATH)
if [ -d "$HOME/.local/share/uv/python" ]; then
    # Find the most recent Python installation
    uv_python_bin=$(find "$HOME/.local/share/uv/python" -maxdepth 2 -type d -name "bin" 2>/dev/null | sort -V | tail -1)
    [ -n "$uv_python_bin" ] && export PATH="$uv_python_bin:$PATH"
fi

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