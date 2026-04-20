#!/usr/bin/env bash
# chezmoi-update-helpers.sh — shared functions for czu/czuf/czl/czm
# Sourced by ~/.local/bin/czu, ~/.local/bin/czuf, ~/.local/bin/czl, and ~/.local/bin/czm

chezmoi_source_dir() {
    printf '%s\n' "$HOME/.local/share/chezmoi"
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

chezmoi_default_branch() {
    local repo data_file branch
    repo="$(chezmoi_source_dir)"
    data_file="$repo/.chezmoidata.toml"
    branch=""

    if [ -f "$data_file" ]; then
        branch="$(
            awk '
                /^\[git\]$/ { in_git=1; next }
                /^\[/ && $0 !~ /^\[git\]$/ { in_git=0 }
                in_git && $1 == "defaultBranch" {
                    gsub(/"/, "", $3)
                    print $3
                    exit
                }
            ' "$data_file"
        )"
    fi

    if [ -z "$branch" ]; then
        branch="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || true)"
    fi

    printf '%s\n' "${branch:-master}"
}

chezmoi_prepare_jj_update() {
    local repo branch
    repo="$(chezmoi_source_dir)"
    branch="$(chezmoi_default_branch)"
    if [ "${VERBOSE:-false}" = "true" ]; then
        jj -R "$repo" git fetch
        jj -R "$repo" rebase -d "$branch"
        return
    fi
    jj --quiet -R "$repo" git fetch
    jj --quiet -R "$repo" rebase -d "$branch"
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
