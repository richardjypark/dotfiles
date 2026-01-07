#!/bin/sh
# Fix for zsh-autosuggestions ZLE errors and IFS issues
# This file addresses the "not enough arguments for -C" issue

# Only run if we're in zsh
[ -n "$ZSH_VERSION" ] || return

# Save original IFS
_ORIGINAL_IFS="$IFS"

# Ensure IFS is properly set for completion functions
# The issue occurs when IFS doesn't contain space, tab, and newline, breaking completion parsing
# Force IFS to default values: space, tab, newline
export IFS=$' \t\n'

# Ensure completion system is properly loaded before autosuggestions
# This prevents the ZLE widget errors
if [[ -o interactive ]]; then
    # Only initialize completion in interactive shells
    autoload -Uz compinit
    
    # Use a more recent compinit dump to avoid permission issues
    local comp_dump="$HOME/.zcompdump-${ZSH_VERSION}"
    if [[ -f "$comp_dump" && "$comp_dump" -nt "$comp_dump.zwc" ]]; then
        compinit -C -d "$comp_dump"
    else
        compinit -d "$comp_dump"
    fi
fi

# Verify that essential ZLE widgets exist before autosuggestions tries to use them
if [[ -o zle ]]; then
    # Ensure basic ZLE functionality is available
    autoload -Uz zle-line-init
    autoload -Uz zle-line-finish
    
    # Check if basic completion widgets are available
    if ! zle -la | grep -q 'complete-word'; then
        # Force reload of completion system
        autoload -Uz compinit && compinit -C -d "$HOME/.zcompdump-${ZSH_VERSION}"
    fi
fi

# Set autosuggestions configuration to be more robust and memory-efficient
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
export ZSH_AUTOSUGGEST_USE_ASYNC=1
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# Limit history search depth for suggestions (memory optimization)
export ZSH_AUTOSUGGEST_HISTORY_IGNORE="?(#c100,)"

# Disable problematic completion features that might cause ZLE errors
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
export ZSH_AUTOSUGGEST_CLEAR_WIDGETS=(
    history-search-forward
    history-search-backward
    history-beginning-search-forward
    history-beginning-search-backward
    history-substring-search-up
    history-substring-search-down
    up-line-or-beginning-search
    down-line-or-beginning-search
    up-line-or-history
    down-line-or-history
    accept-line
)

# Create a hook to restore IFS after all plugins are loaded
_restore_ifs() {
    if [[ -n "$_ORIGINAL_IFS" ]]; then
        export IFS="$_ORIGINAL_IFS"
    fi
}

# Only restore IFS if it was problematic to begin with
if [[ "$_ORIGINAL_IFS" != $' \t\n' ]] && [[ "$_ORIGINAL_IFS" != "" ]]; then
    # Set up a hook to restore IFS after Oh My Zsh loads
    typeset -g _ifs_restore_needed=1
else
    # IFS was fine, no need to restore
    unset _ORIGINAL_IFS
fi 