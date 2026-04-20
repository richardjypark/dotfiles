#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

PI_AGENT_DIR="$HOME/.pi/agent"
PI_LOCAL_SETTINGS_DIR="$HOME/.config/dotfiles/pi"
PI_LOCAL_SETTINGS_FILE="$PI_LOCAL_SETTINGS_DIR/settings.local.json"
PI_LOCAL_KEYBINDINGS_FILE="$PI_LOCAL_SETTINGS_DIR/keybindings.local.json"
PI_SETTINGS_FILE="$PI_AGENT_DIR/settings.json"
PI_KEYBINDINGS_FILE="$PI_AGENT_DIR/keybindings.json"

apply_local_override() {
    local source_file="$1"
    local target_file="$2"

    if [ ! -f "$source_file" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$target_file")"
    install -m 600 "$source_file" "$target_file"
    eecho "Applied local Pi override from: $source_file"
}

apply_local_override "$PI_LOCAL_SETTINGS_FILE" "$PI_SETTINGS_FILE"
apply_local_override "$PI_LOCAL_KEYBINDINGS_FILE" "$PI_KEYBINDINGS_FILE"
