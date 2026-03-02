#!/bin/zsh
# bat compatibility and defaults for shell previews/pagers.
[ -n "$ZSH_VERSION" ] || return

if [[ -z "${DOTFILES_BAT_CMD:-}" ]]; then
  if command -v bat >/dev/null 2>&1; then
    export DOTFILES_BAT_CMD="bat"
  elif command -v batcat >/dev/null 2>&1; then
    export DOTFILES_BAT_CMD="batcat"
  fi
fi

if [[ -n "${DOTFILES_BAT_CMD:-}" ]]; then
  export BAT_PAGER="${BAT_PAGER:-less -RFK}"
  export BAT_STYLE="${BAT_STYLE:-numbers,changes}"
fi
