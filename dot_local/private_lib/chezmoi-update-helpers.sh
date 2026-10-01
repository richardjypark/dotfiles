#!/usr/bin/env bash
# chezmoi-update-helpers.sh — shared functions for czu/czuf/czl/czm
# Sourced by ~/.local/bin/czu, ~/.local/bin/czuf, ~/.local/bin/czl, and ~/.local/bin/czm

# Internal cache: never trust an inherited value that has not passed validation.
CHEZMOI_SOURCE_DIR_RESOLVED=""
CHEZMOI_SOURCE_DIR_RESOLVED_VALID=false

chezmoi_update_error() {
    printf 'chezmoi-update: %s\n' "$*" >&2
}

canonicalize_source_dir() {
    local path="$1"

    case "$path" in
        /*) ;;
        *)
            chezmoi_update_error "source path must be absolute: $path"
            return 1
            ;;
    esac

    if [ ! -d "$path" ]; then
        chezmoi_update_error "source directory does not exist: $path"
        return 1
    fi

    (cd "$path" 2>/dev/null && pwd -P)
}

resolve_chezmoi_source_dir() {
    local source_override legacy_override candidate canonical jj_root

    if [ "${CHEZMOI_SOURCE_DIR_RESOLVED_VALID:-false}" = "true" ] && [ -n "${CHEZMOI_SOURCE_DIR_RESOLVED:-}" ]; then
        export CHEZMOI_SOURCE_DIR="$CHEZMOI_SOURCE_DIR_RESOLVED"
        export CHEZMOI_DIR="$CHEZMOI_SOURCE_DIR_RESOLVED"
        return 0
    fi

    source_override="${CHEZMOI_SOURCE_DIR:-}"
    legacy_override="${CHEZMOI_DIR:-}"

    if [ -n "$source_override" ] && [ -n "$legacy_override" ]; then
        local source_canonical legacy_canonical
        source_canonical="$(canonicalize_source_dir "$source_override")" || return 1
        legacy_canonical="$(canonicalize_source_dir "$legacy_override")" || return 1
        if [ "$source_canonical" != "$legacy_canonical" ]; then
            chezmoi_update_error "CHEZMOI_SOURCE_DIR and CHEZMOI_DIR conflict: $source_canonical != $legacy_canonical"
            return 1
        fi
        candidate="$source_canonical"
    elif [ -n "$source_override" ]; then
        candidate="$source_override"
    elif [ -n "$legacy_override" ]; then
        candidate="$legacy_override"
    else
        if ! command -v chezmoi >/dev/null 2>&1; then
            chezmoi_update_error "chezmoi is required to resolve the source path"
            return 1
        fi
        if ! candidate="$(chezmoi source-path 2>/dev/null)" || [ -z "$candidate" ]; then
            chezmoi_update_error "chezmoi source-path failed; set CHEZMOI_SOURCE_DIR explicitly"
            return 1
        fi
    fi

    canonical="$(canonicalize_source_dir "$candidate")" || return 1
    if [ ! -f "$canonical/.chezmoidata.toml" ]; then
        chezmoi_update_error "source directory is missing .chezmoidata.toml: $canonical"
        return 1
    fi

    if ! command -v jj >/dev/null 2>&1; then
        chezmoi_update_error "jj is required to update the chezmoi source repository"
        return 1
    fi
    if ! jj_root="$(jj --ignore-working-copy -R "$canonical" root 2>/dev/null)"; then
        chezmoi_update_error "source directory is not a jj repository: $canonical"
        return 1
    fi
    jj_root="$(canonicalize_source_dir "$jj_root")" || return 1
    if [ "$jj_root" != "$canonical" ]; then
        chezmoi_update_error "source directory is not the jj workspace root: $canonical (root: $jj_root)"
        return 1
    fi

    CHEZMOI_SOURCE_DIR_RESOLVED="$canonical"
    CHEZMOI_SOURCE_DIR_RESOLVED_VALID=true
    export CHEZMOI_SOURCE_DIR="$canonical"
    export CHEZMOI_DIR="$canonical"
}

chezmoi_source_dir() {
    resolve_chezmoi_source_dir || return $?
    printf '%s\n' "$CHEZMOI_SOURCE_DIR_RESOLVED"
}

run_chezmoi_with_source() {
    local arg

    for arg in "$@"; do
        if [ "$arg" = "--" ]; then
            break
        fi
        case "$arg" in
            --source|--source=*|-S|-S?*)
                chezmoi_update_error "pass the source through CHEZMOI_SOURCE_DIR instead of a second --source/-S argument"
                return 2
                ;;
        esac
    done

    resolve_chezmoi_source_dir || return $?
    command chezmoi --source "$CHEZMOI_SOURCE_DIR_RESOLVED" "$@"
}

is_omarchy_host() {
    command -v omarchy-menu >/dev/null 2>&1 \
        || [ -d "$HOME/.config/omarchy/current" ] \
        || [ -d "$HOME/.local/share/omarchy" ]
}

set_default_chezmoi_profile() {
    [ -z "${CHEZMOI_PROFILE:-}" ] || return 0
    local saved_profile
    saved_profile="$(chezmoi data --format=json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("profile", ""))' 2>/dev/null || true)"
    [ -z "$saved_profile" ] || return 0
    if is_omarchy_host; then export CHEZMOI_PROFILE=omarchy; fi
}

parse_cz_maintenance_args() {
    local command_name="$1"
    shift

    CZ_MAINTENANCE_SYSTEM_ONLY=false
    CZ_MAINTENANCE_BUMP_EXPLICIT=false
    CZ_MAINTENANCE_PLAN=false
    CZ_MAINTENANCE_HELP=false
    VERBOSE="${VERBOSE:-false}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --system-only) CZ_MAINTENANCE_SYSTEM_ONLY=true ;;
            --bump-pins) CZ_MAINTENANCE_BUMP_EXPLICIT=true ;;
            --plan) CZ_MAINTENANCE_PLAN=true ;;
            --verbose|-v) VERBOSE=true ;;
            --help|-h) CZ_MAINTENANCE_HELP=true ;;
            *)
                printf '%s: unknown argument: %s\n' "$command_name" "$1" >&2
                return 2
                ;;
        esac
        shift
    done

    if [ "$CZ_MAINTENANCE_SYSTEM_ONLY" = "true" ] && [ "$CZ_MAINTENANCE_BUMP_EXPLICIT" = "true" ]; then
        printf '%s: --system-only conflicts with --bump-pins\n' "$command_name" >&2
        return 2
    fi

    export VERBOSE
}

maintenance_run() {
    if [ "${VERBOSE:-false}" = "true" ]; then
        printf '+ '
        printf '%q ' "$@"
        printf '\n'
    fi
    "$@"
}

chezmoi_jj_diff_summary() {
    resolve_chezmoi_source_dir || return $?
    jj -R "$CHEZMOI_SOURCE_DIR_RESOLVED" diff -r @ --summary
}

require_clean_chezmoi_source_for_bump() {
    local command_name="$1"
    local summary

    if ! summary="$(chezmoi_jj_diff_summary)"; then
        chezmoi_update_error "failed to inspect the current jj working-copy change"
        return 1
    fi

    if [ -n "$summary" ]; then
        printf '%s: pin-bump mode requires a clean current jj change.\n' "$command_name" >&2
        printf '%s: commit/split the source changes, or rerun with --system-only.\n' "$command_name" >&2
        printf '%s\n' "$summary" >&2
        return 1
    fi
}

chezmoi_source_has_changes() {
    local summary

    summary="$(chezmoi_jj_diff_summary)" || return 2
    [ -n "$summary" ]
}

require_clean_chezmoi_reviewed_source() {
    local summary
    summary="$(chezmoi_jj_diff_summary)" || return 1
    if [ -n "$summary" ]; then
        chezmoi_update_error "--reviewed requires a clean current change; save or split local source work first"
        return 1
    fi
}

require_merged_chezmoi_source() {
    local repo conflicts summary
    resolve_chezmoi_source_dir || return $?
    repo="$CHEZMOI_SOURCE_DIR_RESOLVED"
    conflicts="$(jj -R "$repo" log -r 'conflicts() & @' --no-graph --template commit_id)" || return 1
    if [ -n "$conflicts" ]; then
        chezmoi_update_error "source sync produced a conflict; resolve it before apply"
        return 1
    fi
    summary="$(jj -R "$repo" diff --from 'trunk()' --to @ --summary)" || return 1
    if [ -n "$summary" ]; then
        chezmoi_update_error "source contains changes outside the merged remote default branch; reviewed apply stopped"
        return 1
    fi
}

record_reviewed_chezmoi_update() {
    local revision state_dir
    if ! command -v chezmoi-health-check >/dev/null 2>&1; then
        chezmoi_update_error "chezmoi-health-check is required to record a reviewed update"
        return 1
    fi
    chezmoi-health-check || return $?
    require_merged_chezmoi_source || return $?
    revision="$(jj -R "$CHEZMOI_SOURCE_DIR_RESOLVED" log -r 'trunk()' --no-graph --template commit_id)" || return 1
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-maintenance"
    case "$state_dir" in /*) ;; *) chezmoi_update_error "maintenance state path must be absolute"; return 1 ;; esac
    (
        umask 077
        python3 - "$state_dir" "$revision" <<'PY'
import json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path
state, revision = Path(sys.argv[1]), sys.argv[2]
if not re.fullmatch(r'[0-9a-f]{40}', revision):
    raise SystemExit('Invalid reviewed source revision')
if state.is_symlink():
    raise SystemExit('Maintenance state directory cannot be a symlink')
state.mkdir(parents=True, exist_ok=True, mode=0o700)
state.chmod(0o700)
target = state / 'last-reviewed-update.json'
temporary = state / ('last-reviewed-update.tmp.' + str(os.getpid()))
with temporary.open('x') as output:
    json.dump({'schema': 1, 'revision': revision, 'completedAt': datetime.now(timezone.utc).isoformat(), 'health': 'passed'}, output)
    output.write('\n')
temporary.replace(target)
PY
    )
}

chezmoi_plan_jj_update() {
    local repo remote

    resolve_chezmoi_source_dir || return $?
    repo="$CHEZMOI_SOURCE_DIR_RESOLVED"
    remote="${CHEZMOI_JJ_REMOTE:-${JJ_REMOTE:-origin}}"

    if ! command -v jj-sync-trunk >/dev/null 2>&1; then
        chezmoi_update_error "jj-sync-trunk is required but was not found in PATH"
        return 1
    fi

    if [ "${VERBOSE:-false}" = "true" ]; then
        (cd "$repo" && maintenance_run jj-sync-trunk --dry-run --no-fetch --remote "$remote") || return $?
        return 0
    fi

    (cd "$repo" && jj-sync-trunk --dry-run --no-fetch --remote "$remote" >/dev/null) || return $?
}

chezmoi_prepare_jj_update() {
    local repo remote

    resolve_chezmoi_source_dir || return $?
    repo="$CHEZMOI_SOURCE_DIR_RESOLVED"
    remote="${CHEZMOI_JJ_REMOTE:-${JJ_REMOTE:-origin}}"

    if ! command -v jj-sync-trunk >/dev/null 2>&1; then
        chezmoi_update_error "jj-sync-trunk is required but was not found in PATH"
        return 1
    fi

    if [ "${VERBOSE:-false}" = "true" ]; then
        (cd "$repo" && jj-sync-trunk --remote "$remote") || return $?
        (cd "$repo" && jj -R "$repo" rebase -d 'trunk()') || return $?
        return
    fi

    (cd "$repo" && jj-sync-trunk --remote "$remote" >/dev/null) || return $?
    (cd "$repo" && jj --quiet -R "$repo" rebase -d 'trunk()') || return $?
}

sanitize_terminal_noise() {
    perl -pe 's/\eO//g; s/\e\[\?997;1n//g'
}

run_with_optional_output_sanitizer() {
    if [ -t 1 ]; then
        "$@" 2>&1 | sanitize_terminal_noise
        return "${PIPESTATUS[0]}"
    fi
    "$@"
}

# Use the same runtime resolver as apply-time setup.
CHEZMOI_UPDATE_HELPERS_DIR="${BASH_SOURCE[0]%/*}"
if [ "$CHEZMOI_UPDATE_HELPERS_DIR" = "${BASH_SOURCE[0]}" ]; then CHEZMOI_UPDATE_HELPERS_DIR=.; fi
. "$CHEZMOI_UPDATE_HELPERS_DIR/chezmoi/npm.sh" || return 1
