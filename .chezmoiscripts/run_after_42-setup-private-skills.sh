#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

CONFIG_FILE="$HOME/.config/dotfiles/private-skills.repos"
SKILLS_DIR="$HOME/.agents/skills"
DEFAULT_CHECKOUT_ROOT="$HOME/.local/share/private-skills"
CHECKOUTS=()

if [ ! -f "$CONFIG_FILE" ]; then
    vecho "Private skills are not configured on this host"
    exit 0
fi
if ! is_installed git; then
    eecho "Private skills: git is not installed; skipping"
    exit 0
fi

checkout_path() {
    case "$1" in
        \~) printf '%s\n' "$HOME" ;;
        \~/*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$HOME" "$1" ;;
    esac
}

repo_name() {
    local name="${1%/}"
    name="${name##*/}"
    name="${name##*:}"
    printf '%s\n' "${name%.git}"
}

sync_checkout() {
    local url="$1" dir="$2"
    if [ ! -d "$dir/.git" ]; then
        if [ -e "$dir" ]; then
            eecho "Private skills: $dir exists and is not a Git checkout; skipping"
            return 1
        fi
        mkdir -p "$(dirname "$dir")"
        if ! git clone --quiet "$url" "$dir" < /dev/null; then
            eecho "Private skills: could not clone a configured repo into $dir; skipping"
            return 1
        fi
        return 0
    fi
    if ! is_force_update; then
        return 0
    fi
    if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
        eecho "Private skills: $dir has local changes; not pulling"
    elif ! git -C "$dir" pull --ff-only --quiet < /dev/null; then
        eecho "Private skills: could not update $dir; keeping the current checkout"
    fi
}

is_private_path() {
    local root
    for root in "$DEFAULT_CHECKOUT_ROOT" ${CHECKOUTS[@]+"${CHECKOUTS[@]}"}; do
        case "$1" in "$root"/*) return 0 ;; esac
    done
    return 1
}

prune_stale_links() {
    local link
    for link in "$SKILLS_DIR"/*; do
        [ -L "$link" ] && [ ! -e "$link" ] || continue
        is_private_path "$(readlink "$link")" || continue
        rm -f -- "$link"
        vecho "Private skills: removed stale link ${link##*/}"
    done
}

link_skills() {
    local skill name target current
    for skill in "$1"/skills/*/; do
        [ -f "${skill}SKILL.md" ] || continue
        skill="${skill%/}"
        name="${skill##*/}"
        target="$SKILLS_DIR/$name"
        if [ -L "$target" ]; then
            current="$(readlink "$target")"
            [ "$current" != "$skill" ] || continue
            if [ -e "$target" ] || ! is_private_path "$current"; then
                eecho "Private skills: $target already links to $current; skipping $name"
                continue
            fi
        elif [ -e "$target" ]; then
            eecho "Private skills: $target is a managed or local folder; skipping $name"
            continue
        fi
        ln -sfn "$skill" "$target"
        vecho "Private skills: linked $name"
    done
}

while read -r url dir _ <&3 || [ -n "${url:-}" ]; do
    case "$url" in '' | '#'*) continue ;; esac
    if [ -n "${dir:-}" ]; then
        dir="$(checkout_path "$dir")"
    else
        dir="$DEFAULT_CHECKOUT_ROOT/$(repo_name "$url")"
    fi
    sync_checkout "$url" "$dir" || continue
    CHECKOUTS+=("$(cd "$dir" && pwd -P)")
done 3< "$CONFIG_FILE"

mkdir -p "$SKILLS_DIR"
prune_stale_links
for dir in ${CHECKOUTS[@]+"${CHECKOUTS[@]}"}; do
    link_skills "$dir"
done
