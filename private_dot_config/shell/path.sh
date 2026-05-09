#!/bin/sh
# PATH Management - Central location for all PATH modifications
# This file is loaded by ~/.zshrc for interactive shells

# Helper function to add paths without duplicates
# Usage: path_prepend /new/path
path_prepend() {
    [ -n "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;  # Already in PATH, skip
        *)
            if [ -n "${PATH:-}" ]; then
                export PATH="$1:$PATH"
            else
                export PATH="$1"
            fi
            ;;
    esac
}

# Usage: path_append /new/path
path_append() {
    [ -n "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;  # Already in PATH, skip
        *)
            if [ -n "${PATH:-}" ]; then
                export PATH="$PATH:$1"
            else
                export PATH="$1"
            fi
            ;;
    esac
}

# Drop inherited duplicate PATH entries once for faster command lookup.
# Empty entries are omitted to avoid implicitly searching the current directory.
path_dedup() {
    _old_path="${PATH:-}"
    _new_path=""

    while [ -n "$_old_path" ]; do
        case "$_old_path" in
            *:*)
                _path_entry="${_old_path%%:*}"
                _old_path="${_old_path#*:}"
                ;;
            *)
                _path_entry="$_old_path"
                _old_path=""
                ;;
        esac

        [ -n "$_path_entry" ] || continue
        case ":$_new_path:" in
            *":$_path_entry:"*) ;;
            *)
                if [ -n "$_new_path" ]; then
                    _new_path="$_new_path:$_path_entry"
                else
                    _new_path="$_path_entry"
                fi
                ;;
        esac
    done

    export PATH="$_new_path"
    unset _old_path _new_path _path_entry
}

path_dedup

# Base directories (highest priority first)
# Note: ~/.local/bin is already in PATH from ~/.zshenv (for all shells)
path_prepend "$HOME/bin"
path_prepend "/usr/local/bin"

# uv-managed Python (add latest installed version to PATH, cached for speed)
if [ -d "$HOME/.local/share/uv/python" ]; then
    _uv_cache="$HOME/.cache/uv-python-bin"
    _uv_dir="$HOME/.local/share/uv/python"
    if [ ! -f "$_uv_cache" ] || [ "$_uv_dir" -nt "$_uv_cache" ]; then
        mkdir -p "$HOME/.cache"
        if command -v python3 >/dev/null 2>&1; then
            find "$_uv_dir" -maxdepth 2 -type d -name "bin" 2>/dev/null | python3 -c 'import re, sys; paths=[p.strip() for p in sys.stdin if p.strip()]; version=lambda p: tuple(map(int, re.search(r"(\d+(?:\.\d+)+)", p).group(1).split("."))) if re.search(r"(\d+(?:\.\d+)+)", p) else (); print(sorted(paths, key=lambda p: (version(p), p))[-1] if paths else "")' > "$_uv_cache"
        elif sort -V </dev/null >/dev/null 2>&1; then
            find "$_uv_dir" -maxdepth 2 -type d -name "bin" 2>/dev/null | sort -V | tail -1 > "$_uv_cache"
        else
            find "$_uv_dir" -maxdepth 2 -type d -name "bin" 2>/dev/null | sort | tail -1 > "$_uv_cache"
        fi
    fi
    uv_python_bin=""
    IFS= read -r uv_python_bin < "$_uv_cache" 2>/dev/null || uv_python_bin=""
    [ -n "$uv_python_bin" ] && path_prepend "$uv_python_bin"
fi

# Platform-specific paths
case "${OSTYPE:-$(uname -s)}" in
    darwin*|Darwin*)
        # macOS-specific paths

        # Homebrew OpenJDK 17 path (keg-only)
        jdk17_bin="/opt/homebrew/opt/openjdk@17/bin"
        [ -d "$jdk17_bin" ] && path_prepend "$jdk17_bin"

        # Cursor IDE
        cursor_path="/Applications/Cursor.app/Contents/Resources/app/bin"
        [ -d "$cursor_path" ] && path_append "$cursor_path"
        ;;
    linux*|Linux*)
        # Linux-specific paths

        # Cursor IDE
        cursor_path="$HOME/.local/share/cursor/bin"
        [ -d "$cursor_path" ] && path_append "$cursor_path"
        ;;
esac

# Clean up helper functions
unset -f path_prepend path_append path_dedup
