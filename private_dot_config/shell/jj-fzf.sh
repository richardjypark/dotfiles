#!/bin/zsh
# jj + fzf interactive workflows
# Requires: jj, fzf (0.54+ for become())
[ -n "$ZSH_VERSION" ] || return
(( $+commands[jj] )) && (( $+commands[fzf] )) || return

# Resolve delta command once for interactive diff viewing.
__dotfiles_jj_delta_cmd="${DOTFILES_DELTA_CMD:-}"
if [[ -z "$__dotfiles_jj_delta_cmd" ]]; then
  if command -v delta >/dev/null 2>&1; then
    __dotfiles_jj_delta_cmd="delta"
  fi
fi

if [[ -n "$__dotfiles_jj_delta_cmd" ]]; then
  export DOTFILES_DELTA_CMD="$__dotfiles_jj_delta_cmd"
  __dotfiles_jj_diff_bind="ctrl-d:execute(jj diff -r {1} --color=never | $__dotfiles_jj_delta_cmd --paging=always)"
  __dotfiles_jj_file_preview='jj diff -r REV --ignore-working-copy --color=never -- {} | DELTA --paging=never'
  __dotfiles_jj_file_preview="${__dotfiles_jj_file_preview/DELTA/$__dotfiles_jj_delta_cmd}"
fi

# Resolve bat command once for interactive diff viewing.
__dotfiles_jj_bat_cmd="${DOTFILES_BAT_CMD:-}"
if [[ -z "$__dotfiles_jj_bat_cmd" ]]; then
  if command -v bat >/dev/null 2>&1; then
    __dotfiles_jj_bat_cmd="bat"
  elif command -v batcat >/dev/null 2>&1; then
    __dotfiles_jj_bat_cmd="batcat"
  fi
fi

if [[ -n "${__dotfiles_jj_diff_bind:-}" ]] && [[ -n "${__dotfiles_jj_file_preview:-}" ]]; then
  :
elif [[ -n "$__dotfiles_jj_bat_cmd" ]]; then
  export DOTFILES_BAT_CMD="$__dotfiles_jj_bat_cmd"
  __dotfiles_jj_diff_bind="ctrl-d:execute(jj diff -r {1} --color=always | $__dotfiles_jj_bat_cmd --language=diff --paging=always --style=plain)"
  __dotfiles_jj_file_preview='jj diff -r REV --ignore-working-copy --color=always -- {} | BAT --language=diff --paging=never --style=plain'
  __dotfiles_jj_file_preview="${__dotfiles_jj_file_preview/BAT/$__dotfiles_jj_bat_cmd}"
else
  __dotfiles_jj_diff_bind='ctrl-d:execute(jj diff -r {1} --color=always | less -R)'
  __dotfiles_jj_file_preview='jj diff -r REV --ignore-working-copy --color=always -- {}'
fi

__jj_fzf_check() {
  jj root --ignore-working-copy >/dev/null 2>&1 || {
    echo "Not in a jj repository." >&2; return 1
  }
}

# jji - Interactive jj log browser
# Usage: jji [revset]  (default: all())
jji() {
  __jj_fzf_check || return 1
  local revset="${1:-all()}"
  jj log --no-graph --ignore-working-copy --color=always \
    -T 'change_id.short() ++ "\t" ++ change_id.shortest() ++ " " ++ surround("[", "] ", bookmarks) ++ if(empty, "(empty) ", "") ++ if(description, description.first_line(), "(no description)") ++ "\n"' \
    -r "$revset" |
  fzf --ansi \
      --delimiter='\t' --with-nth=2.. \
      --preview 'jj show -r {1} --ignore-working-copy --color=always' \
      --preview-window 'right,60%,border-left,wrap' \
      --header 'enter:edit  C-n:new-after  C-d:diff  C-s:squash  C-r:rebase-here' \
      --bind 'enter:become(jj edit {1})' \
      --bind 'ctrl-n:become(jj new -A {1})' \
      --bind "$__dotfiles_jj_diff_bind" \
      --bind 'ctrl-s:become(jj squash --from {1})' \
      --bind 'ctrl-r:become(jj rebase -s {1} -d @)'
}

# jjbi - Interactive jj bookmark browser
jjbi() {
  __jj_fzf_check || return 1
  jj bookmark list --ignore-working-copy --color=always \
    -T 'if(tracked, "", name ++ "\t" ++ name ++ " -> " ++ if(normal_target, normal_target.change_id().shortest() ++ " " ++ if(normal_target.description(), normal_target.description().first_line(), "(no desc)"), "???") ++ "\n")' |
  fzf --ansi \
      --delimiter='\t' --with-nth=2.. \
      --preview 'jj log -r {1} --ignore-working-copy --color=always' \
      --preview-window 'right,60%,border-left' \
      --header 'enter:edit  C-p:push  C-d:delete  C-m:move-here' \
      --bind 'enter:become(jj edit {1})' \
      --bind 'ctrl-p:become(jj git push -b {1})' \
      --bind 'ctrl-d:become(jj bookmark delete {1})' \
      --bind 'ctrl-m:become(jj bookmark move --to @ {1})'
}

# jjfi - Interactive file diff browser
# Usage: jjfi [revision]  (default: @)
jjfi() {
  __jj_fzf_check || return 1
  local rev="${1:-@}"
  local preview_cmd="${__dotfiles_jj_file_preview/REV/$rev}"
  jj diff -r "$rev" --name-only --ignore-working-copy |
  fzf --ansi \
      --preview "$preview_cmd" \
      --preview-window 'right,60%,border-left,wrap' \
      --header 'enter:open  C-r:restore' \
      --bind "enter:become(${EDITOR:-vi} {})" \
      --bind "ctrl-r:become(jj restore -r $rev {})"
}
