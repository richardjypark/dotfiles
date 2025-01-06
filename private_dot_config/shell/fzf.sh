#!/bin/sh
# FZF configuration
export FZF_BASE="$HOME/.local/share/fzf"

# Interactive ripgrep with file preview and vim integration
rgi() {
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  INITIAL_QUERY="${*:-}"
  fzf --ansi --disabled --query "$INITIAL_QUERY" \
      --bind "start:reload:$RG_PREFIX {q}" \
      --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
      --delimiter : \
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
      --bind 'enter:become(vim {1} +{2})'
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
      --preview 'bat --color=always {1} --highlight-line {2}' \
      --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
}
export FZF_DEFAULT_OPTS="
  --height 80% 
  --layout reverse 
  --border 
  --preview-window 'right,50%,border-left' 
  --bind 'ctrl-/:toggle-preview'
"

source <(fzf --zsh)
