#!/usr/bin/env bash
# Claude Code status line. Claude Code sends session JSON on stdin; this script
# prints one line:
#   host project[/subdir] <branch symbol> branch[*] [wt:worktree] model·effort │ context N% left │ 5-hour limit N% left
# Percentages show what REMAINS (context window, rate limits).
# Field reference: https://code.claude.com/docs/en/statusline
# Keep this script compatible with bash 3.2 (macOS /bin/bash) and BSD tools.

input=$(cat)

model="" effort="" fast="false" cwd="" proj="" wt="" ctx="" h5="" h5_reset="" d7=""
eval "$(jq -r '
  def left: if . == null then "" else (100 - . | floor) end;
  @sh "model=\(.model.display_name // "")
       effort=\(.effort.level // "")
       fast=\(.fast_mode // false)
       cwd=\(.workspace.current_dir // .cwd // "")
       proj=\(.workspace.project_dir // "")
       wt=\(.worktree.name // .workspace.git_worktree // "")
       ctx=\(.context_window.remaining_percentage | if . == null then "" else floor end)
       h5=\(.rate_limits.five_hour.used_percentage | left)
       h5_reset=\(.rate_limits.five_hour.resets_at // "")
       d7=\(.rate_limits.seven_day.used_percentage | left)"
' <<<"$input" 2>/dev/null)"

# Basic ANSI colors only, so the line follows the terminal theme.
rst=$'\033[0m' dim=$'\033[2m' bold=$'\033[1m'
red=$'\033[31m' green=$'\033[32m' yellow=$'\033[33m'
blue=$'\033[34m' magenta=$'\033[35m' cyan=$'\033[36m'
# Nerd Font / Powerline branch symbol U+E0A0, as UTF-8 bytes for bash 3.2.
branch_glyph=$'\xee\x82\xa0'

# Green above 50% left, yellow from 21% to 50%, red at 20% or less.
pct_color() {
  if (($1 <= 20)); then
    printf '%s' "$red"
  elif (($1 <= 50)); then
    printf '%s' "$yellow"
  else
    printf '%s' "$green"
  fi
}

out="${dim}${HOSTNAME:-$(hostname)}${rst}"

# Project directory, plus the current subdirectory when it is different.
[[ -z $proj ]] && proj=$cwd
[[ -n $proj ]] && out+=" ${bold}${blue}${proj##*/}${rst}"
if [[ -n $cwd && $cwd != "$proj" ]]; then
  if [[ $cwd == "$proj"/* ]]; then
    out+="${blue}/${cwd#"$proj"/}${rst}"
  else
    out+="${dim}→${rst}${blue}${cwd##*/}${rst}"
  fi
fi

# Branch. Yellow with "*" = uncommitted changes, green = clean.
# A colocated jj repo has a detached Git HEAD, so use the nearest jj bookmark
# (or the jj change ID). A plain detached HEAD shows as "@<commit>".
if [[ -n $cwd ]] && git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null)
  if [[ -z $branch ]] && command -v jj >/dev/null 2>&1; then
    branch=$(cd "$cwd" && jj log --ignore-working-copy --no-graph \
      -r 'heads(::@ & bookmarks())' \
      -T 'local_bookmarks.map(|b| b.name()).join(",") ++ "\n"' 2>/dev/null | paste -sd, -)
    if [[ -z $branch ]]; then
      branch=$(cd "$cwd" && jj log --ignore-working-copy --no-graph -r @ \
        -T '"@" ++ change_id.shortest(4)' 2>/dev/null)
    fi
  fi
  if [[ -z $branch ]]; then
    branch="@$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)"
  fi
  if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null ||
    ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; then
    out+=" ${yellow}${branch_glyph} ${branch}*${rst}"
  else
    out+=" ${green}${branch_glyph} ${branch}${rst}"
  fi
fi

# Worktree: shown only inside a linked Git worktree or a Claude worktree session.
[[ -n $wt ]] && out+=" ${magenta}wt:${wt}${rst}"

[[ -n ${VIRTUAL_ENV:-} ]] && out+=" ${dim}venv:${VIRTUAL_ENV##*/}${rst}"

# Model, effort level, and a fast-mode mark.
if [[ -n $model ]]; then
  out+=" ${cyan}${model}${rst}"
  [[ -n $effort ]] && out+="${dim}·${rst}${effort}"
  [[ $fast == "true" ]] && out+="${yellow}⚡${rst}"
fi

# Context window that remains.
sep=" ${dim}│${rst} "
[[ -n $ctx ]] && out+="${sep}${dim}context${rst} $(pct_color "$ctx")${ctx}% left${rst}"

# 5-hour rate limit that remains. The reset time shows at 20% or less.
if [[ -n $h5 ]]; then
  out+="${sep}${dim}5-hour limit${rst} $(pct_color "$h5")${h5}% left${rst}"
  if ((h5 <= 20)) && [[ -n $h5_reset ]]; then
    reset=$(date -d "@$h5_reset" +%H:%M 2>/dev/null || date -r "$h5_reset" +%H:%M 2>/dev/null)
    [[ -n $reset ]] && out+=" ${dim}resets ${reset}${rst}"
  fi
fi

# 7-day rate limit: shown only when 20% or less remains.
[[ -n $d7 ]] && ((d7 <= 20)) && out+="${sep}${dim}7-day limit${rst} ${red}${d7}% left${rst}"

printf '%s' "$out"
