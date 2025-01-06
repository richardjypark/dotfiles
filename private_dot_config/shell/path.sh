#!/bin/sh
# Base PATH
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Cursor PATH (cross-platform)
case "$(uname -s)" in
    Darwin*)    
        cursor_path="/Applications/Cursor.app/Contents/Resources/app/bin"
        ;;
    Linux*)     
        cursor_path="$HOME/.local/share/cursor/bin"
        ;;
esac
[ -d "$cursor_path" ] && export PATH="$PATH:$cursor_path"