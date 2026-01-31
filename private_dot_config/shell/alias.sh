# Shell Config Shortcuts
alias zh='${EDITOR:-vim} ~/.zsh_history'          # Edit zsh history

# Jujutsu (jj) - additional aliases beyond OMZ jj plugin
alias j='jj'                                      # 1-keystroke shortcut

# Chezmoi with jj (avoids detached HEAD issues)
alias czu='jj -R ~/.local/share/chezmoi git fetch && jj -R ~/.local/share/chezmoi new master && chezmoi apply'  # Update dotfiles via jj
alias czuf='jj -R ~/.local/share/chezmoi git fetch && jj -R ~/.local/share/chezmoi new master && chezmoi apply --refresh-externals --force'  # Full update with externals

# Legacy git aliases (keep for non-jj repos)
alias gaa="git add -A"
alias gcam='git commit --amend --no-edit'

# AI Tools
alias c='claude'                              # Claude Code CLI