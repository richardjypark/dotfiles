#!/usr/bin/env bash
# Remove the agent guide copies that older versions of these dotfiles wrote
# to ~/AGENTS.md, ~/CLAUDE.md, and ~/.codex/AGENTS.md. The guide now applies
# to the dotfiles repo only. chezmoi does not remove ignored targets, so this
# runs once per machine. A file that does not look like a dotfiles copy is
# kept and reported.
set -euo pipefail

remove_if_managed() {
    local file="$1" header="$2"
    local top
    [ -f "$file" ] && [ ! -L "$file" ] || return 0
    top="$(head -n 5 "$file")"
    if [ "${top%%$'\n'*}" = "$header" ] && grep -Eq "chezmoi|dotfiles|@AGENTS\.md" <<<"$top"; then
        rm -f -- "$file"
        echo "Removed old dotfiles agent guide: $file"
    else
        echo "Kept $file: it is not a dotfiles copy" >&2
    fi
}

remove_if_managed "$HOME/AGENTS.md" "# AGENTS.md"
remove_if_managed "$HOME/.codex/AGENTS.md" "# AGENTS.md"
remove_if_managed "$HOME/CLAUDE.md" "# CLAUDE.md"
