[[ -n "${ZSH_VERSION:-}" ]] || return 0

autoload -Uz add-zsh-hook

typeset -gx DOTFILES_JJ_PROMPT="${DOTFILES_JJ_PROMPT:-}"
typeset -g _DOTFILES_JJ_ROOT="${_DOTFILES_JJ_ROOT:-}"
typeset -gi _DOTFILES_JJ_STALE="${_DOTFILES_JJ_STALE:-1}"
typeset -g _DOTFILES_TMUX_STATUS_SEGMENT="${_DOTFILES_TMUX_STATUS_SEGMENT:-}"

_dotfiles_trim() {
  emulate -L zsh
  setopt local_options extended_glob

  local value="${1-}"
  value="${value##[[:space:]]##}"
  value="${value%%[[:space:]]##}"
  print -r -- "$value"
}

_dotfiles_sanitize_label() {
  emulate -L zsh

  local label="${(L)1}"
  label="${label//[^[:alnum:]_.-]/}"
  [[ -n "$label" ]] || label="unknown"
  print -r -- "$label"
}

_dotfiles_is_ipv4() {
  emulate -L zsh

  local value="${1-}"
  local -a octets
  octets=("${(@s:.:)value}")
  (( ${#octets} == 4 )) || return 1

  local octet
  for octet in "${octets[@]}"; do
    [[ "$octet" == <-> ]] || return 1
    (( octet <= 255 )) || return 1
  done
}

_dotfiles_looks_like_ip() {
  emulate -L zsh

  local value="${1-}"
  [[ -n "$value" ]] || return 1

  case "$value" in
    (*:*)
      [[ "$value" != *[^0-9a-fA-F:.]* ]]
      return
      ;;
  esac

  _dotfiles_is_ipv4 "$value"
}

_dotfiles_normalize_host() {
  emulate -L zsh

  local host
  host="$(_dotfiles_trim "${1-}")"
  host="${host#\[}"
  host="${host%\]}"
  host="${host##*@}"
  host="${host%%,*}"
  host="${host%%/*}"

  if _dotfiles_looks_like_ip "$host"; then
    print -r -- "remote"
    return 0
  fi

  host="${host%%:*}"
  host="${host%%.*}"
  _dotfiles_sanitize_label "$host"
}

_dotfiles_valid_color() {
  emulate -L zsh

  local color
  color="$(_dotfiles_trim "${1-}")"
  case "$color" in
    (""|*[^[:alnum:]_-]*)
      return 1
      ;;
  esac
}

_dotfiles_resolve_host_alias() {
  emulate -L zsh

  local raw_input="${1-}"
  local fallback_alias="${2:-unknown}"
  local default_fg="${3:-colour255}"
  local default_bg="${4:-colour238}"
  local alias_file="${TMUX_HOST_ALIAS_FILE:-${HOME}/.config/tmux/host-aliases.conf}"
  local key alias fg bg

  key="$(_dotfiles_normalize_host "$raw_input")"
  alias="$fallback_alias"
  fg="$default_fg"
  bg="$default_bg"

  if [[ -f "$alias_file" ]]; then
    local map_host map_alias map_fg map_bg map_key map_alias_raw
    while IFS='|' read -r map_host map_alias map_fg map_bg _rest; do
      map_host="$(_dotfiles_trim "${map_host:-}")"
      [[ -n "$map_host" ]] || continue
      [[ "$map_host" != \#* ]] || continue

      map_key="$(_dotfiles_normalize_host "$map_host")"
      [[ "$map_key" == "$key" ]] || continue

      map_alias_raw="$(_dotfiles_trim "${map_alias:-}")"
      if [[ -n "$map_alias_raw" ]]; then
        alias="$(_dotfiles_sanitize_label "$map_alias_raw")"
      fi

      if _dotfiles_valid_color "${map_fg:-}"; then
        fg="$(_dotfiles_trim "$map_fg")"
      fi
      if _dotfiles_valid_color "${map_bg:-}"; then
        bg="$(_dotfiles_trim "$map_bg")"
      fi
      break
    done < "$alias_file"
  fi

  alias="$(_dotfiles_sanitize_label "$alias")"
  print -r -- "${alias}|${fg}|${bg}"
}

_dotfiles_tmux_render_segment() {
  emulate -L zsh

  local context="${1:-LOCAL}"
  local host_input="${2:-unknown}"
  local fallback_alias="${3:-unknown}"
  local default_fg="${4:-colour255}"
  local default_bg="${5:-colour238}"
  local alias_data alias_label alias_fg alias_bg context_segment remainder

  alias_data="$(_dotfiles_resolve_host_alias "$host_input" "$fallback_alias" "$default_fg" "$default_bg")"
  alias_label="${alias_data%%|*}"
  remainder="${alias_data#*|}"
  alias_fg="${remainder%%|*}"
  alias_bg="${remainder##*|}"

  case "$context" in
    (OUTER_SSH)
      context_segment='#[fg=colour231,bg=colour160,bold] SSH '
      ;;
    (INNER_REMOTE)
      context_segment='#[fg=colour231,bg=colour125,bold] REMOTE '
      ;;
    (*)
      context_segment='#[fg=colour250,bg=colour238,bold] LOCAL '
      ;;
  esac

  print -r -- "${context_segment}#[fg=${alias_fg},bg=${alias_bg},bold] ${alias_label} "
}

_dotfiles_tmux_set_segment() {
  emulate -L zsh

  [[ -n "${TMUX:-}" ]] || return 0
  [[ -n "${TMUX_PANE:-}" ]] || return 0
  (( $+commands[tmux] )) || return 0

  local segment="${1-}"
  [[ "$segment" == "$_DOTFILES_TMUX_STATUS_SEGMENT" ]] && return 0

  _DOTFILES_TMUX_STATUS_SEGMENT="$segment"
  tmux set-option -pq -t "$TMUX_PANE" @dotfiles_status_host "$segment" 2>/dev/null || true
}

_dotfiles_tmux_sync_default() {
  emulate -L zsh

  local host_short="${${HOST:-local}%%.*}"
  local segment

  if [[ -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]; then
    segment="$(_dotfiles_tmux_render_segment "INNER_REMOTE" "$host_short" "remote" "colour232" "colour111")"
  else
    segment="$(_dotfiles_tmux_render_segment "LOCAL" "$host_short" "$host_short" "colour232" "colour45")"
  fi

  _dotfiles_tmux_set_segment "$segment"
}

_dotfiles_sanitize_command_text() {
  emulate -L zsh

  local text="${1-}"
  text="${text//$'\003'/}"
  text="${text//$'\r'/}"
  print -r -- "$text"
}

_dotfiles_command_words() {
  emulate -L zsh

  local command_line
  command_line="$(_dotfiles_sanitize_command_text "$1")"
  reply=("${(z)command_line}")
}

_dotfiles_command_index() {
  emulate -L zsh

  local -a words
  local index token

  _dotfiles_command_words "$1"
  words=("${reply[@]}")

  for (( index = 1; index <= ${#words}; index++ )); do
    token="${words[index]}"
    case "$token" in
      (noglob|nocorrect|builtin|command|time)
        continue
        ;;
      (env)
        continue
        ;;
      (sudo|doas)
        continue
        ;;
      ([[:alpha:]_][[:alnum:]_]*=*)
        continue
        ;;
      (*)
        REPLY="$index"
        return 0
        ;;
    esac
  done

  REPLY=""
  return 1
}

_dotfiles_extract_remote_host() {
  emulate -L zsh

  local cmdline="$1"
  local command_name="$2"
  local -a words
  local index token
  local skip_next=0

  _dotfiles_command_words "$cmdline"
  words=("${reply[@]}")
  _dotfiles_command_index "$cmdline" || return 1
  index="$REPLY"

  for (( index += 1; index <= ${#words}; index++ )); do
    token="${words[index]}"

    if (( skip_next )); then
      skip_next=0
      continue
    fi

    [[ -n "$token" ]] || continue

    case "$command_name" in
      (ssh)
        case "$token" in
          (--*)
            continue
            ;;
          (-[1246AaCfGgKkMNnqsTtVvXxYy])
            continue
            ;;
          (-[bceDEeFIiJLlmOopQRSWw])
            skip_next=1
            continue
            ;;
          (-[bceDEeFIiJLlmOopQRSWw]?*)
            continue
            ;;
          (-*)
            continue
            ;;
          (*)
            print -r -- "$token"
            return 0
            ;;
        esac
        ;;
      (mosh|mosh-client)
        case "$token" in
          (--*)
            continue
            ;;
          (-*)
            continue
            ;;
          (*)
            print -r -- "$token"
            return 0
            ;;
        esac
        ;;
    esac
  done

  return 1
}

_dotfiles_should_refresh_jj_for_command() {
  emulate -L zsh

  local token="${1-}"
  case "$token" in
    (jj|j|jst|jd|jl|jcmsg|jdmsg|jn|je|jsq|jrb|jf|jp)
      return 0
      ;;
  esac

  return 1
}

_dotfiles_jj_clear() {
  emulate -L zsh

  _DOTFILES_JJ_ROOT=""
  _DOTFILES_JJ_STALE=0
  unset DOTFILES_JJ_PROMPT
}

_dotfiles_jj_within_cached_root() {
  emulate -L zsh

  [[ -n "$_DOTFILES_JJ_ROOT" ]] || return 1
  case "${PWD:A}" in
    ($_DOTFILES_JJ_ROOT|$_DOTFILES_JJ_ROOT/*)
      return 0
      ;;
  esac
  return 1
}

_dotfiles_jj_refresh() {
  emulate -L zsh

  (( $+commands[jj] )) || {
    _dotfiles_jj_clear
    return 0
  }

  local repo_root label
  repo_root="$(command jj root --ignore-working-copy 2>/dev/null)" || {
    _dotfiles_jj_clear
    return 0
  }

  if [[ "$repo_root" == "$_DOTFILES_JJ_ROOT" && $_DOTFILES_JJ_STALE -eq 0 ]]; then
    return 0
  fi

  label="$(command jj log --no-graph --ignore-working-copy -r @ -T 'if(bookmarks, bookmarks.join(","), change_id.shortest())' 2>/dev/null)" || {
    _DOTFILES_JJ_ROOT="$repo_root"
    _DOTFILES_JJ_STALE=0
    unset DOTFILES_JJ_PROMPT
    return 0
  }

  _DOTFILES_JJ_ROOT="$repo_root"
  _DOTFILES_JJ_STALE=0
  export DOTFILES_JJ_PROMPT="jj:${label}"
}

_dotfiles_prompt_state_chpwd() {
  emulate -L zsh

  if _dotfiles_jj_within_cached_root && [[ $_DOTFILES_JJ_STALE -eq 0 ]]; then
    return 0
  fi

  _DOTFILES_JJ_STALE=1
  _dotfiles_jj_refresh
}

_dotfiles_prompt_state_precmd() {
  emulate -L zsh

  if [[ $_DOTFILES_JJ_STALE -ne 0 ]]; then
    _dotfiles_jj_refresh
  fi

  _dotfiles_tmux_sync_default
}

_dotfiles_prompt_state_preexec() {
  emulate -L zsh

  local cmdline
  local -a words
  local index command_name remote_host

  cmdline="$(_dotfiles_sanitize_command_text "$1")"
  _dotfiles_command_words "$cmdline"
  words=("${reply[@]}")
  _dotfiles_command_index "$cmdline" || return 0
  index="$REPLY"
  command_name="${words[index]}"

  if _dotfiles_should_refresh_jj_for_command "$command_name"; then
    _DOTFILES_JJ_STALE=1
  fi

  case "$command_name" in
    (ssh|mosh|mosh-client)
      remote_host="$(_dotfiles_extract_remote_host "$cmdline" "$command_name")"
      [[ -n "$remote_host" ]] || remote_host="remote"
      _dotfiles_tmux_set_segment "$(_dotfiles_tmux_render_segment "OUTER_SSH" "$remote_host" "remote" "colour255" "colour52")"
      ;;
  esac
}

_dotfiles_accept_line() {
  emulate -L zsh

  local sanitized
  sanitized="${BUFFER//$'\003'/}"
  sanitized="${sanitized//$'\r'/}"

  if [[ -n "$sanitized" && "$sanitized" != "$BUFFER" ]]; then
    BUFFER="$sanitized"
    CURSOR="${#BUFFER}"
  fi

  zle .accept-line
}

add-zsh-hook chpwd _dotfiles_prompt_state_chpwd
add-zsh-hook precmd _dotfiles_prompt_state_precmd
add-zsh-hook preexec _dotfiles_prompt_state_preexec
zle -N accept-line _dotfiles_accept_line
