#!/bin/zsh
# History configuration - zsh only
[ -n "$ZSH_VERSION" ] || return

# Security: Restrict history file permissions (readable only by owner)
[[ -f "$HOME/.zsh_history" ]] && chmod 600 "$HOME/.zsh_history"

# History file configuration
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000                  # Maximum events for internal history
SAVEHIST=50000                  # Maximum events in history file

# History command configuration
setopt EXTENDED_HISTORY         # Write the history file in the ':start:elapsed;command' format
setopt INC_APPEND_HISTORY       # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY            # Share history between all sessions
setopt HIST_EXPIRE_DUPS_FIRST   # Expire a duplicate event first when trimming history
setopt HIST_IGNORE_DUPS         # Do not record an event that was just recorded again
setopt HIST_IGNORE_ALL_DUPS     # Delete an old recorded event if a new event is a duplicate
setopt HIST_FIND_NO_DUPS        # Do not display a previously found event
setopt HIST_IGNORE_SPACE        # Do not record an event starting with a space
setopt HIST_SAVE_NO_DUPS        # Do not write a duplicate event to the history file
setopt HIST_VERIFY              # Do not execute immediately upon history expansion
setopt HIST_REDUCE_BLANKS       # Remove superfluous blanks from each command line

# Format history timestamp
alias history='fc -li 1'        # Use ISO 8601 standard for timestamps

# Time format for extended history
export HIST_STAMPS="yyyy-mm-dd"
