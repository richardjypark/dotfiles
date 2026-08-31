#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

BIN_DIR="$FIXTURE/bin"
CALL_LOG="$FIXTURE/calls.log"
REPO_DIR="$FIXTURE/repo"
STATE_DIR="$FIXTURE/state"
mkdir -p "$BIN_DIR" "$REPO_DIR" "$STATE_DIR" "$FIXTURE/home"
: > "$CALL_LOG"

make_stub() {
    local name="$1"
    local body="$2"

    {
        printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
        printf '%s\n' "$body"
    } > "$BIN_DIR/$name"
    chmod +x "$BIN_DIR/$name"
}

make_stub flock 'exit 0'
make_stub ssh 'printf "ssh|%s\n" "$*" >> "$TEST_CALL_LOG"'
make_stub czuf 'printf "czuf|%s\n" "$*" >> "$TEST_CALL_LOG"'
make_stub chezmoi-bump 'printf "chezmoi-bump|%s\n" "$*" >> "$TEST_CALL_LOG"'
make_stub chezmoi 'printf "chezmoi|%s\n" "$*" >> "$TEST_CALL_LOG"'
make_stub date 'printf "2026-08-31T17:01:00-04:00\n"'
make_stub jj '
printf "jj|%s\n" "$*" >> "$TEST_CALL_LOG"
case "$*" in
    *"diff --summary"*) exit 0 ;;
    *"@ & conflicts()"*) exit 0 ;;
esac
'
make_stub pi 'printf "pi|%s\n" "$*" >> "$TEST_CALL_LOG"'

output_file="$FIXTURE/output.log"
if ! HOME="$FIXTURE/home" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_CALL_LOG="$CALL_LOG" \
    CHEZMOI_REPO_DIR="$REPO_DIR" \
    STATE_DIR="$STATE_DIR" \
    RUNTIME_ENV_FILE="$FIXTURE/missing.env" \
    PI_BIN="$BIN_DIR/pi" \
    GIT_SSH_COMMAND="$BIN_DIR/ssh" \
        bash "$PROJECT_DIR/bin/executable_run-maintenance.sh" > "$output_file" 2>&1; then
    printf '%s\n' 'maintenance entrypoint failed:' >&2
    sed 's/^/  /' "$output_file" >&2
    exit 1
fi

assert_call() {
    local expected="$1"
    if ! grep -Fq -- "$expected" "$CALL_LOG"; then
        printf 'missing call: %s\n' "$expected" >&2
        printf '%s\n' '--- calls ---' >&2
        sed 's/^/  /' "$CALL_LOG" >&2
        exit 1
    fi
}

assert_call 'czuf|'
assert_call 'chezmoi-bump|neovim jj codex uv starship bun tailscale chezmoi nvm fzf zsh-syntax-highlighting zsh-autosuggestions'
assert_call 'chezmoi|apply --refresh-externals --force'
assert_call 'jj|-R'

if grep -Fq -- 'pi|' "$CALL_LOG"; then
    printf 'pi should not run when there are no tracked changes\n' >&2
    exit 1
fi

if ! grep -Fq -- 'no tracked changes to publish' "$output_file"; then
    printf 'missing no-change completion message\n' >&2
    exit 1
fi

printf 'Pi maintenance no-change flow passed\n'
