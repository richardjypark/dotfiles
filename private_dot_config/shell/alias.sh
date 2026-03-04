# Shell Config Shortcuts
alias zh='${EDITOR:-vi} ~/.zsh_history'            # Edit zsh history

# Prefer Neovim when available
if command -v nvim >/dev/null 2>&1; then
  alias vi='nvim'
  alias vim='nvim'
fi

# Prefer eza/exa for interactive directory listings.
if [[ -z "${DOTFILES_EZA_CMD:-}" ]]; then
  if command -v eza >/dev/null 2>&1; then
    export DOTFILES_EZA_CMD="eza"
  elif command -v exa >/dev/null 2>&1; then
    export DOTFILES_EZA_CMD="exa"
  fi
fi

if [[ -n "${DOTFILES_EZA_CMD:-}" ]]; then
  alias ls="${DOTFILES_EZA_CMD} --group-directories-first --icons=auto"
  alias ll="${DOTFILES_EZA_CMD} -lh --group-directories-first --icons=auto"
  alias la="${DOTFILES_EZA_CMD} -lha --group-directories-first --icons=auto"
  alias lt="${DOTFILES_EZA_CMD} --tree --level=2 --group-directories-first --icons=auto"

  # Preserve exa muscle memory after migrating to eza.
  if [[ "${DOTFILES_EZA_CMD}" = "eza" ]]; then
    alias exa="eza"
  fi
fi

# Prefer delta for interactive diffs.
if command -v delta >/dev/null 2>&1; then
  export DOTFILES_DELTA_CMD="delta"
  unalias diff 2>/dev/null || true

  # Keep diff-compatible behavior: use delta for simple 2-file diffs,
  # and fall back to system diff for flag-heavy or recursive use.
  diff() {
    emulate -L zsh

    if (( $# != 2 )); then
      command diff "$@"
      return $?
    fi

    if [[ "$1" == -* || "$2" == -* || -d "$1" || -d "$2" ]]; then
      command diff "$@"
      return $?
    fi

    "$DOTFILES_DELTA_CMD" "$1" "$2"
  }
fi

# Jujutsu (jj) - additional aliases beyond OMZ jj plugin
alias j='jj'                                      # 1-keystroke shortcut
alias jst='jj status'                             # like gst
alias jd='jj diff'                                # like gd
alias jl='jj log'                                 # like gl
alias jcmsg='jj commit --message'                 # like gcmsg
alias jdmsg='jj describe --message'               # like gcmsg --amend
alias jn='jj new'                                 # new change
alias je='jj edit'                                # edit a revision
alias jsq='jj squash'                             # like squash merge
alias jrb='jj rebase'                             # like grb
alias jf='jj git fetch'                           # like gf
alias jp='jj git push'                            # like gp

# Chezmoi helper commands are defined in ~/.config/shell/chezmoi.sh
alias czvc='chezmoi-check-versions'               # Check pinned dependency versions
alias czb='chezmoi-bump'                          # Bump pinned dependency versions

# Legacy git aliases (keep for non-jj repos)
alias gaa="git add -A"
alias gcam='git commit --amend --no-edit'

# AI Tools
alias c='claude'                              # Claude Code CLI
