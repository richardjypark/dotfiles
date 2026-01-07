# Shell Config Shortcuts
alias zh='${EDITOR:-vim} ~/.zsh_history'          # Edit zsh history

# Jujutsu (jj) as default VCS - replaces git commands
# Core workflow
alias j='jj'                                      # Quick access
alias js='jj status'                              # Status (like git status)
alias jl='jj log'                                 # Log with default template
alias jd='jj diff'                                # Diff working copy
alias jds='jj diff --stat'                        # Diff with stats
alias jsh='jj show'                               # Show current change

# Committing (jj auto-tracks files, no add needed)
alias jc='jj commit'                              # Commit and start new change
alias jci='jj commit -i'                          # Interactive commit
alias jdesc='jj describe'                         # Edit current change message
alias jn='jj new'                                 # Create new empty change
alias jsq='jj squash'                             # Squash into parent

# Branches (called "bookmarks" in jj)
alias jb='jj bookmark list'                       # List bookmarks
alias jbc='jj bookmark create'                    # Create bookmark
alias jbm='jj bookmark move'                      # Move bookmark
alias jbd='jj bookmark delete'                    # Delete bookmark

# Git interop
alias jgp='jj git push'                           # Push to remote
alias jgf='jj git fetch'                          # Fetch from remote
alias jgc='jj git clone'                          # Clone a repo

# Chezmoi with jj (avoids detached HEAD issues)
alias czu='jj -R ~/.local/share/chezmoi git fetch && jj -R ~/.local/share/chezmoi new master && chezmoi apply'  # Update dotfiles via jj

# Navigation
alias je='jj edit'                                # Edit a specific revision
alias jnext='jj next'                             # Move to child commit
alias jprev='jj prev'                             # Move to parent commit

# Undo/redo
alias jop='jj op log'                             # Operation log (undo history)
alias jundo='jj undo'                             # Undo last operation

# Legacy git aliases (keep for non-jj repos)
alias gaa="git add -A"
alias gcam='git commit --amend --no-edit'

# AI Tools
alias c='claude'                              # Claude Code CLI