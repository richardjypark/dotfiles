#!/bin/zsh
# FZF configuration - zsh only
[ -n "$ZSH_VERSION" ] || return

export FZF_BASE="$HOME/.local/share/fzf"

# Resolve bat command once for all fzf previews.
__dotfiles_bat_cmd="${DOTFILES_BAT_CMD:-}"
if [[ -z "$__dotfiles_bat_cmd" ]]; then
  if command -v bat >/dev/null 2>&1; then
    __dotfiles_bat_cmd="bat"
  elif command -v batcat >/dev/null 2>&1; then
    __dotfiles_bat_cmd="batcat"
  fi
fi

if [[ -n "$__dotfiles_bat_cmd" ]]; then
  export DOTFILES_BAT_CMD="$__dotfiles_bat_cmd"
  __dotfiles_fzf_preview_with_line="$__dotfiles_bat_cmd --color=always --style=numbers --line-range=:500 --highlight-line {2} -- {1}"
else
  __dotfiles_fzf_preview_with_line='sed -n "1,500p" {1}'
fi

# Interactive ripgrep with file preview and editor integration
rgi() {
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  INITIAL_QUERY="${*:-}"
  fzf --ansi --disabled --query "$INITIAL_QUERY" \
      --bind "start:reload:$RG_PREFIX {q}" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --delimiter : \
      --preview "$__dotfiles_fzf_preview_with_line" \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
      --bind "enter:become(${EDITOR:-vi} {1} +{2})"
}
# Switch between ripgrep and fzf modes with CTRL-T
rgf() {
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  fzf --ansi --disabled --query "$*" \
      --bind "start:reload:$RG_PREFIX {q}" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ ripgrep ]] &&
        echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search" ||
        echo "unbind(change)+change-prompt(2. fzf> )+enable-search"' \
      --prompt '1. ripgrep> ' \
      --delimiter : \
      --preview "$__dotfiles_fzf_preview_with_line" \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
}
# Use fd or rg for faster file searching (respects .gitignore)
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS="
  --height=~80%
  --layout=reverse
  --border
  --preview-window 'right,50%,border-left'
  --bind 'ctrl-/:toggle-preview'
  --ansi
"

# Load fzf shell integrations from installed files (more portable than process substitution).
# These scripts restore shell options in a way that can emit harmless zle noise on startup.
[ -f "$FZF_BASE/shell/key-bindings.zsh" ] && source "$FZF_BASE/shell/key-bindings.zsh" 2>/dev/null
[ -f "$FZF_BASE/shell/completion.zsh" ] && source "$FZF_BASE/shell/completion.zsh" 2>/dev/null
