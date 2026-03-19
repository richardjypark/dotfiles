#!/usr/bin/env bash
set -euo pipefail

umask 077

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pi-maintenance-agent"
LOG_DIR="$STATE_DIR/logs"
SESSION_DIR="$STATE_DIR/sessions"
LOCK_FILE="$STATE_DIR/run.lock"
REPO_DIR="${CHEZMOI_REPO_DIR:-$HOME/.local/share/chezmoi}"
RUNTIME_ENV_FILE="${RUNTIME_ENV_FILE:-$HOME/.config/dotfiles/pi-maintenance-agent.env}"
PUBLISH_BOOKMARK="${PUBLISH_BOOKMARK:-master}"
PI_BIN="${PI_BIN:-$PROJECT_DIR/node_modules/.bin/pi}"
PI_PROVIDER="${PI_PROVIDER:-}"
PI_MODEL="${PI_MODEL:-}"
PI_THINKING="${PI_THINKING:-medium}"
TIMESTAMP="$(date '+%Y-%m-%dT%H-%M-%S')"
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"

install -d -m 700 "$STATE_DIR" "$LOG_DIR" "$SESSION_DIR"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  exit 0
fi

if [[ -f "$RUNTIME_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$RUNTIME_ENV_FILE"
  set +a
fi

PI_PROVIDER="${PI_PROVIDER:-}"
PI_MODEL="${PI_MODEL:-}"
PI_THINKING="${PI_THINKING:-medium}"

exec > >(tee -a "$LOG_FILE") 2>&1

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  }
}

has_repo_changes() {
  [[ -n "$(jj -R "$REPO_DIR" diff --summary)" ]]
}

has_repo_conflicts() {
  [[ -n "$(jj -R "$REPO_DIR" log -r '@ & conflicts()' --no-graph -T 'change_id.short() ++ "\n"')" ]]
}

working_copy_descends_from_publish_bookmark() {
  [[ -n "$(jj -R "$REPO_DIR" log -r "${PUBLISH_BOOKMARK}::@" --no-graph -T 'change_id.short() ++ "\n"')" ]]
}

has_empty_intermediate_commits() {
  [[ -n "$(jj -R "$REPO_DIR" log -r "ancestors(@) & descendants(${PUBLISH_BOOKMARK}) & ~${PUBLISH_BOOKMARK} & ~@ & empty()" --no-graph -T 'change_id.short() ++ "\n"')" ]]
}

has_nonempty_intermediate_commits() {
  [[ -n "$(jj -R "$REPO_DIR" log -r "ancestors(@) & descendants(${PUBLISH_BOOKMARK}) & ~${PUBLISH_BOOKMARK} & ~@ & ~empty()" --no-graph -T 'change_id.short() ++ "\n"')" ]]
}

build_pi_args() {
  local -a args
  args=(
    --no-session
    --mode text
    --print
    --session-dir "$SESSION_DIR"
    --thinking "$PI_THINKING"
    --no-extensions
    --no-skills
    --no-prompt-templates
  )

  if [[ -n "$PI_PROVIDER" ]]; then
    args+=(--provider "$PI_PROVIDER")
  fi
  if [[ -n "$PI_MODEL" ]]; then
    args+=(--model "$PI_MODEL")
  fi

  printf '%s\0' "${args[@]}"
}

run_pi_prompt() {
  local prompt_file="$1"
  local tools="$2"
  local prompt_args=()
  while IFS= read -r -d '' arg; do
    prompt_args+=("$arg")
  done < <(build_pi_args)

  (
    cd "$REPO_DIR"
    "$PI_BIN" "${prompt_args[@]}" --tools "$tools" @"$prompt_file"
  )
}

generate_commit_message() {
  local output message

  if ! output="$(run_pi_prompt "$PROJECT_DIR/prompts/publish.md" "read,bash,grep,find,ls")"; then
    return 1
  fi

  message="$(printf '%s\n' "$output" | awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print; exit }')"
  if [[ -z "$message" ]]; then
    printf 'pi did not return a commit message\n' >&2
    return 1
  fi

  printf '%s\n' "$message"
}

is_conventional_commit_message() {
  local message="$1"
  [[ "$message" =~ ^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([[:alnum:]_.-]+\))?!?:[[:space:]].+ ]]
}

main() {
  require_cmd jj
  require_cmd czuf
  require_cmd chezmoi-bump
  require_cmd chezmoi

  export CHEZMOI_DISABLE_SUDO=1

  if [[ ! -x "$PI_BIN" ]]; then
    printf 'pi binary not found: %s\n' "$PI_BIN" >&2
    exit 1
  fi

  printf '==> [%s] running czuf\n' "$(date --iso-8601=seconds)"
  (
    cd "$REPO_DIR"
    czuf
  )

  printf '==> [%s] running chezmoi-bump --all\n' "$(date --iso-8601=seconds)"
  (
    cd "$REPO_DIR"
    chezmoi-bump --all
  )

  printf '==> [%s] re-applying bumped state\n' "$(date --iso-8601=seconds)"
  (
    cd "$REPO_DIR"
    env TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1 \
      chezmoi apply --refresh-externals --force
  )

  printf '==> [%s] checking repo state\n' "$(date --iso-8601=seconds)"
  if has_repo_conflicts; then
    run_pi_prompt "$PROJECT_DIR/prompts/repair.md" "read,bash,edit,write,grep,find,ls"
    exit 1
  fi

  if ! has_repo_changes; then
    printf '==> no tracked changes to publish\n'
    exit 0
  fi

  if ! working_copy_descends_from_publish_bookmark; then
    printf 'working copy is not based on %s; refusing to publish automated changes\n' "$PUBLISH_BOOKMARK" >&2
    exit 1
  fi

  if has_nonempty_intermediate_commits; then
    printf 'found non-empty local commits between %s and @; refusing to publish stacked changes automatically\n' "$PUBLISH_BOOKMARK" >&2
    exit 1
  fi

  if has_empty_intermediate_commits; then
    printf '==> [%s] rebasing current change onto %s to skip stale empty ancestors\n' "$(date --iso-8601=seconds)" "$PUBLISH_BOOKMARK"
    jj -R "$REPO_DIR" rebase -s @ -d "$PUBLISH_BOOKMARK"
  fi

  if ! has_repo_changes; then
    printf '==> no tracked changes remain after ancestry cleanup\n'
    exit 0
  fi

  printf '==> [%s] generating commit message\n' "$(date --iso-8601=seconds)"
  local commit_message
  commit_message="$(generate_commit_message)"
  if [[ "$commit_message" == UNSAFE:* ]]; then
    printf '%s\n' "$commit_message" >&2
    exit 1
  fi
  if ! is_conventional_commit_message "$commit_message"; then
    printf 'pi returned an invalid conventional commit message: %s\n' "$commit_message" >&2
    exit 1
  fi

  printf '==> [%s] publishing %s\n' "$(date --iso-8601=seconds)" "$commit_message"
  jj -R "$REPO_DIR" describe -m "$commit_message"
  jj -R "$REPO_DIR" bookmark move "$PUBLISH_BOOKMARK" --to @
  jj -R "$REPO_DIR" git push -b "$PUBLISH_BOOKMARK"
  jj -R "$REPO_DIR" new "$PUBLISH_BOOKMARK"
}

main "$@"
