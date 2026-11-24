#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
. "$REPO_ROOT/tests/lib/temp.sh"
new_test_temp_dir fixture
trap 'remove_test_temp_dir "$fixture"' EXIT

SCRIPT="$REPO_ROOT/.chezmoiscripts/run_after_42-setup-private-skills.sh"
HOME_DIR="$fixture/home"
SKILLS="$HOME_DIR/.agents/skills"
CONFIG="$HOME_DIR/.config/dotfiles/private-skills.repos"
REMOTE="$fixture/remote/fin.git"
WORK="$fixture/work"

mkdir -p "$HOME_DIR/.local/lib" "$HOME_DIR/.config/dotfiles" "$fixture/remote"
cat > "$HOME_DIR/.local/lib/chezmoi-helpers.sh" <<'EOF'
eecho() { printf '%s\n' "$*"; }
vecho() { :; }
is_installed() { command -v "$1" >/dev/null 2>&1; }
is_force_update() { [ "${CHEZMOI_FORCE_UPDATE:-0}" = "1" ]; }
EOF

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

run_hook() {
    HOME="$HOME_DIR" bash "$SCRIPT" > "$fixture/out" 2>&1 || fail "hook exited non-zero: $(cat "$fixture/out")"
}

add_skill() {
    mkdir -p "$WORK/skills/$1"
    printf -- '---\nname: %s\n---\n' "$1" > "$WORK/skills/$1/SKILL.md"
}

commit_push() {
    git -C "$WORK" add -A
    git -C "$WORK" commit -qm "$1"
    git -C "$WORK" push -q origin HEAD
}

git init -q --bare "$REMOTE"
git clone -q "$REMOTE" "$WORK" 2>/dev/null
add_skill demo
add_skill managed
add_skill foreign
commit_push initial

run_hook
[ ! -e "$SKILLS" ] || fail "hook acted without a config file"
printf '[PASS] no config file is a no-op\n'

mkdir -p "$SKILLS/managed" "$fixture/elsewhere"
ln -s "$fixture/elsewhere" "$SKILLS/foreign"
printf '# private skills\n\n%s\n' "$REMOTE" > "$CONFIG"
run_hook
checkout="$(cd "$HOME_DIR/.local/share/private-skills/fin" && pwd -P)"
[ "$(readlink "$SKILLS/demo")" = "$checkout/skills/demo" ] || fail "demo is not linked to the default checkout"
[ -d "$SKILLS/managed" ] && [ ! -L "$SKILLS/managed" ] || fail "a real skill folder was replaced"
[ "$(readlink "$SKILLS/foreign")" = "$fixture/elsewhere" ] || fail "a foreign symlink was replaced"
grep -Fq "skipping managed" "$fixture/out" || fail "no warning for the real folder"
grep -Fq "skipping foreign" "$fixture/out" || fail "no warning for the foreign symlink"
printf '[PASS] clones the repo, links skills, keeps existing entries\n'

run_hook
[ "$(readlink "$SKILLS/demo")" = "$checkout/skills/demo" ] || fail "rerun changed the link"
printf '[PASS] a repeated run is stable\n'

add_skill second
git -C "$WORK" rm -rq skills/demo
commit_push update
run_hook
[ -L "$SKILLS/demo" ] && [ ! -e "$SKILLS/second" ] || fail "pulled without a forced update"
CHEZMOI_FORCE_UPDATE=1 run_hook
[ -L "$SKILLS/second" ] || fail "a forced update did not link the new skill"
[ ! -L "$SKILLS/demo" ] || fail "the stale link was not removed"
printf '[PASS] a forced update pulls, links new skills, removes stale links\n'

add_skill third
commit_push third
printf 'local edit\n' > "$checkout/skills/second/notes.md"
CHEZMOI_FORCE_UPDATE=1 run_hook
grep -Fq "has local changes" "$fixture/out" || fail "no warning for a dirty checkout"
[ ! -e "$SKILLS/third" ] || fail "pulled into a dirty checkout"
rm "$checkout/skills/second/notes.md"
printf '[PASS] a dirty checkout is not pulled\n'

printf '%s ~/dev/fin-custom\n%s\n' "$REMOTE" "$fixture/remote/missing.git" > "$CONFIG"
run_hook
custom="$(cd "$HOME_DIR/dev/fin-custom" && pwd -P)"
[ "$(readlink "$SKILLS/second")" = "$checkout/skills/second" ] || fail "an existing live link was replaced by a second checkout"
[ "$(readlink "$SKILLS/third")" = "$custom/skills/third" ] || fail "the custom checkout was not linked"
grep -Fq "could not clone" "$fixture/out" || fail "no warning for a failed clone"
printf '[PASS] custom checkout paths work and a failed clone only warns\n'
