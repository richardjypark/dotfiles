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
    if [ -z "${CHEZMOI_PROFILE:-}" ] && is_omarchy_host; then
        export CHEZMOI_PROFILE="omarchy"
    fi
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

resolve_npm_cmd() {
    local nvm_dir current_node nvm_bin candidate resolved

    nvm_dir="$HOME/.nvm"
    if [ -f "$nvm_dir/nvm.sh" ]; then
        . "$nvm_dir/nvm.sh" >/dev/null 2>&1 || true
        if command -v nvm >/dev/null 2>&1; then
            nvm use default >/dev/null 2>&1 || true
            current_node="$(nvm which current 2>/dev/null || true)"
            if [ -n "$current_node" ] && [ -x "$current_node" ]; then
                nvm_bin="$(dirname "$current_node")"
                if [ -x "$nvm_bin/npm" ] && "$nvm_bin/npm" -v >/dev/null 2>&1; then
                    printf '%s\n' "$nvm_bin/npm"
                    return 0
                fi
            fi
        fi
    fi

    if command -v npm >/dev/null 2>&1; then
        candidate="$(command -v npm)"
        resolved="$candidate"
        if command -v readlink >/dev/null 2>&1; then
            resolved="$(readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate")"
        fi
        if [ -x "$resolved" ] && "$resolved" -v >/dev/null 2>&1; then
            printf '%s\n' "$resolved"
            return 0
        fi
        if [ -x "$candidate" ] && "$candidate" -v >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    return 1
}
