#!/usr/bin/env bash
# chezmoi-update-helpers.sh — shared functions for czu and czuf
# Sourced by ~/.local/bin/czu and ~/.local/bin/czuf

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
