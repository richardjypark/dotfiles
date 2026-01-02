#!/bin/zsh
# Jujutsu (jj) configuration - zsh only
[ -n "$ZSH_VERSION" ] || return

# Load jj completions if jj is available
if command -v jj >/dev/null 2>&1; then
    # Use dynamic completions (recommended) with caching for performance
    local jj_comp="$HOME/.cache/jj-completion.zsh"
    local jj_bin="$(command -v jj)"

    # Regenerate cache if jj binary is newer or cache doesn't exist
    if [[ ! -f "$jj_comp" ]] || [[ "$jj_bin" -nt "$jj_comp" ]]; then
        mkdir -p "$HOME/.cache"
        COMPLETE=zsh jj > "$jj_comp" 2>/dev/null
    fi

    [[ -f "$jj_comp" ]] && source "$jj_comp"
fi
