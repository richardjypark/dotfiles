#!/usr/bin/env bash
set -u

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGINAL_PATH="$PATH"

PASS_COUNT=0
FAIL_COUNT=0
LAST_STATUS=0
LAST_SOURCE=""
LAST_CALLS=""
LAST_OUT=""
TEST_FIXTURE_ROOT=""

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1"
    return 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [ "$actual" = "$expected" ]; then
        pass "$msg"
        return 0
    fi
    fail "$msg (got=$actual expected=$expected)"
}

assert_ne() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [ "$actual" != "$expected" ]; then
        pass "$msg"
        return 0
    fi
    fail "$msg (unexpectedly = $actual)"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if [ -f "$file" ] && grep -Fq -- "$pattern" "$file"; then
        pass "$msg"
        return 0
    fi
    fail "$msg"
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if [ -f "$file" ] && ! grep -Fq -- "$pattern" "$file"; then
        pass "$msg"
        return 0
    fi
    fail "$msg"
}

assert_call_count_ge() {
    local file="$1"
    local pattern="$2"
    local minimum="$3"
    local msg="$4"
    local count

    count="$(grep -F -- "$pattern" "$file" | wc -l | tr -d ' ')"
    if [ "$count" -ge "$minimum" ]; then
        pass "$msg (count=$count)"
        return 0
    fi
    fail "$msg (count=$count minimum=$minimum)"
}

assert_order() {
    local file="$1"
    local first="$2"
    local second="$3"
    local msg="$4"
    local first_line second_line

    first_line="$(grep -nF -- "$first" "$file" | head -n1 | cut -d: -f1)"
    second_line="$(grep -nF -- "$second" "$file" | head -n1 | cut -d: -f1)"

    if [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ]; then
        pass "$msg"
        return 0
    fi
    fail "$msg"
}

reset_test_state() {
    export JJ_DIFF_SUMMARY_PRE=""
    export JJ_DIFF_SUMMARY_POST=""
    export JJ_DIFF_SUMMARY=""
    export JJ_DIFF_STATUS="0"
    export CHEZMOI_BUMP_TOUCH="0"
    export CHEZMOI_BUMP_STATUS="0"
    export BREW_CLEANUP_FAIL="0"
    export CHECK_UPDATES_OUTPUT=""
    export CHECK_UPDATES_STATUS="0"
    export PACMAN_QUERY_STATUS="0"
    export HOMEBREW_NO_AUTO_UPDATE=""
    export EXPECT_VERBOSE="0"
    export SHASUM_MODE="incremental"
}

create_fixture() {
    local root="$1"
    local source="$root/source"

    mkdir -p \
        "$source/.jj" \
        "$source/dot_local/share/pi-cli" \
        "$source/dot_local/share/pi-maintenance-agent" \
        "$source/.local/share/pi-cli" \
        "$source/.local/share/pi-maintenance-agent" \
        "$source/dot_pi/agent" \
        "$root/.local/lib" \
        "$root/bin"
    : > "$root/calls.log"
    : > "$root/jj-diff-index"
    : > "$root/shasum.count"

    printf '%s\n' "[chezmoi]" > "$source/.chezmoidata.toml"
    printf '%s\n' "[git]" > "$source/.chezmoiversion.toml"
    printf '%s\n' "[external]" > "$source/.chezmoiexternal.toml.tmpl"
    printf '{"name":"pi-cli"}\n' > "$source/dot_local/share/pi-cli/package.json"
    printf '{"name":"pi-maintenance-agent"}\n' > "$source/dot_local/share/pi-maintenance-agent/package.json"
    printf '{"name":"pi-cli-lock"}\n' > "$source/dot_local/share/pi-cli/package-lock.json"
    printf '{"name":"pi-maintenance-lock"}\n' > "$source/dot_local/share/pi-maintenance-agent/package-lock.json"
    printf '{"last":1}\n' > "$source/dot_pi/agent/settings.json"

    cp "$SCRIPT_ROOT/dot_local/private_lib/chezmoi-update-helpers.sh" "$root/.local/lib/chezmoi-update-helpers.sh"

    cat > "$root/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"

log_call() {
    printf 'CMD|chezmoi|args=%s|CHEZMOI_SOURCE_DIR=%s|CHEZMOI_DIR=%s|VERBOSE=%s|CHEZMOI_MACOS_MAINTENANCE_MODE=%s\n' \
        "$*" "${CHEZMOI_SOURCE_DIR-<unset>}" "${CHEZMOI_DIR-<unset>}" "${VERBOSE-<unset>}" "${CHEZMOI_MACOS_MAINTENANCE_MODE-<unset>}" >> "$log_file"
}

log_call "$@"

if [ "${1-}" = "source-path" ]; then
    printf '%s\n' "${CHEZMOI_STUB_SOURCE:-$HOME/.local/share/chezmoi}"
    exit "${CHEZMOI_SOURCE_PATH_STATUS:-0}"
fi

if [ "${1-}" = "diff" ]; then
    printf '%s\n' "${CHEZMOI_DIFF_OUTPUT:-}"
    exit 0
fi

if [ "${1-}" = "apply" ]; then
    if [ "${EXPECT_CHEZMOI_SOURCE_ARG:-0}" = "1" ] && [ "${CHEZMOI_DIR-}" = "" ]; then
        echo "expected CHEZMOI_DIR for selected source" >&2
        exit 3
    fi
fi

exit "${CHEZMOI_STATUS:-0}"
EOF
    chmod +x "$root/bin/chezmoi"

    cat > "$root/bin/jj" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
diff_index_file="${JJ_DIFF_INDEX_FILE:-${TEST_CALL_LOG}.jj.diff-index}"

has_root=0
has_diff=0
has_summary=0
for arg in "$@"; do
    case "$arg" in
        root) has_root=1 ;;
        diff) has_diff=1 ;;
        --summary) has_summary=1 ;;
    esac
done

printf 'CMD|jj|args=%s\n' "$*" >> "$log_file"

if [ "$has_root" -eq 1 ] && [ "$has_diff" -eq 0 ]; then
    printf '%s\n' "${JJ_STUB_ROOT:-$HOME/.local/share/chezmoi}"
    exit "${JJ_STUB_ROOT_STATUS:-0}"
fi

if [ "$has_diff" -eq 1 ] && [ "$has_summary" -eq 1 ]; then
    count="$(cat "$diff_index_file" 2>/dev/null || true)"
    count="${count:-0}"
    count=$((count + 1))
    printf '%s' "$count" > "$diff_index_file"

    if [ "$count" -eq 1 ]; then
        printf '%s\n' "${JJ_DIFF_SUMMARY_PRE:-${JJ_DIFF_SUMMARY:-}}"
    else
        printf '%s\n' "${JJ_DIFF_SUMMARY_POST:-${JJ_DIFF_SUMMARY:-}}"
    fi
    exit "${JJ_DIFF_STATUS:-0}"
fi

exit "${JJ_STUB_STATUS:-0}"
EOF
    chmod +x "$root/bin/jj"

    cat > "$root/bin/jj-sync-trunk" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"

if [ "${EXPECT_VERBOSE:-0}" = "1" ] && [ "${VERBOSE:-false}" != "true" ]; then
    printf 'CMD|jj-sync-trunk|args=%s|VERBOSE=%s|blocking=1\n' "$*" "${VERBOSE-<unset>}" >> "$log_file"
    exit 72
fi

printf 'CMD|jj-sync-trunk|args=%s|VERBOSE=%s\n' "$*" "${VERBOSE-<unset>}" >> "$log_file"
exit "${JJ_SYNC_STATUS:-0}"
EOF
    chmod +x "$root/bin/jj-sync-trunk"

    cat > "$root/bin/czuf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
printf 'CMD|czuf|args=%s|VERBOSE=%s|CHEZMOI_MACOS_MAINTENANCE_MODE=%s\n' \
    "$*" "${VERBOSE-<unset>}" "${CHEZMOI_MACOS_MAINTENANCE_MODE-<unset>}" >> "$log_file"
exit "${CZUF_STATUS:-0}"
EOF
    chmod +x "$root/bin/czuf"

    cat > "$root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
printf 'CMD|sudo|args=%s\n' "$*" >> "$log_file"
if [ "${SUDO_STATUS:-0}" -ne 0 ]; then
    exit "$SUDO_STATUS"
fi
if [ "${1:-}" = "-v" ]; then
    exit 0
fi
exec "$@"
EOF
    chmod +x "$root/bin/sudo"

    cat > "$root/bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
cmd="$1"
printf 'CMD|pacman|args=%s\n' "$*" >> "$log_file"

if [ "$cmd" = "-Syu" ] && [ "${PACMAN_UPDATE_FAIL:-0}" = "1" ]; then
    exit 1
fi

if [ "$cmd" = "-Syu" ] || [ "$cmd" = "-Qu" ]; then
    printf '%s\n' "${PACMAN_OUT:-}"
fi
if [ "$cmd" = "-Qu" ]; then
    exit "${PACMAN_QUERY_STATUS:-0}"
fi
exit 0
EOF
    chmod +x "$root/bin/pacman"

    cat > "$root/bin/checkupdates" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
printf 'CMD|checkupdates|args=%s\n' "$*" >> "$log_file"
printf '%s\n' "${CHECK_UPDATES_OUTPUT:-}"
exit "${CHECK_UPDATES_STATUS:-0}"
EOF
    chmod +x "$root/bin/checkupdates"

    cat > "$root/bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
printf 'CMD|brew|args=%s|HOMEBREW_NO_AUTO_UPDATE=%s\n' "$*" "${HOMEBREW_NO_AUTO_UPDATE-<unset>}" >> "$log_file"

case "$1" in
    outdated)
        printf '%s\n' "${BREW_OUTDATED_OUTPUT:-}"
        ;;
    cleanup)
        if [ "${BREW_CLEANUP_FAIL:-0}" = "1" ]; then
            echo "brew cleanup simulated failure" >&2
            exit 1
        fi
        ;;
    *)
        ;;
esac

exit 0
EOF
    chmod +x "$root/bin/brew"

    cat > "$root/bin/chezmoi-bump" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"

printf 'CMD|chezmoi-bump|args=%s|CHEZMOI_DIR=%s\n' "$*" "${CHEZMOI_DIR-<unset>}" >> "$log_file"

is_dry_run=0
for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && is_dry_run=1

done

if [ "$is_dry_run" -eq 0 ] && [ "${CHEZMOI_BUMP_TOUCH:-0}" = "1" ] && [ -n "${CHEZMOI_DIR:-}" ]; then
    printf 'bumped\n' >> "$CHEZMOI_DIR/.chezmoidata.toml"
fi

exit "${CHEZMOI_BUMP_STATUS:-0}"
EOF
    chmod +x "$root/bin/chezmoi-bump"

    cat > "$root/bin/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log_file="${TEST_CALL_LOG:?missing TEST_CALL_LOG}"
count_file="${SHASUM_COUNT_FILE:-${TEST_CALL_LOG}.shasum-count}"

count="$(cat "$count_file" 2>/dev/null || true)"
count="${count:-0}"
count=$((count + 1))
printf '%s' "$count" > "$count_file"

printf 'CMD|shasum|args=%s\n' "$*" >> "$log_file"

sum="hash-$count"
if [ "${SHASUM_MODE:-incremental}" = "constant" ]; then
    sum=hash-constant
fi

last_arg="${!#}"
printf '%s  %s\n' "$sum" "$last_arg"
EOF
    chmod +x "$root/bin/shasum"
}

run_wrapper() {
    local fixture="$1"
    local wrapper="$2"
    local ostype="$3"
    shift 3
    local args=("$@")

    LAST_SOURCE="$fixture/source"
    LAST_OUT="$fixture/${wrapper}.out"
    LAST_CALLS="$fixture/calls.log"

    : > "$LAST_OUT"
    : > "$LAST_CALLS"
    : > "$fixture/jj-diff-index"
    : > "$fixture/shasum.count"

    if (
        export HOME="$fixture"
        export PATH="$fixture/bin:$ORIGINAL_PATH"
        export OSTYPE="$ostype"
        export TEST_CALL_LOG="$LAST_CALLS"
        export STUB_JJ_DIFF_INDEX="$fixture/jj-diff-index"
        export TEST_SOURCE_DIR="$LAST_SOURCE"
        export JJ_DIFF_INDEX_FILE="$fixture/jj-diff-index"
        export CHEZMOI_SOURCE_DIR=""
        export CHEZMOI_DIR=""
        export CHEZMOI_STUB_SOURCE="$LAST_SOURCE"
        export CHEZMOI_BUMP_TOUCH="${CHEZMOI_BUMP_TOUCH:-0}"
        export CHEZMOI_BUMP_STATUS="${CHEZMOI_BUMP_STATUS:-0}"
        export SHASUM_MODE="${SHASUM_MODE:-incremental}"
        export JJ_DIFF_SUMMARY_PRE="${JJ_DIFF_SUMMARY_PRE:-}"
        export JJ_DIFF_SUMMARY_POST="${JJ_DIFF_SUMMARY_POST:-}"
        export JJ_DIFF_SUMMARY="${JJ_DIFF_SUMMARY:-}"
        export JJ_DIFF_STATUS="${JJ_DIFF_STATUS:-0}"
        export BREW_CLEANUP_FAIL="${BREW_CLEANUP_FAIL:-0}"
        export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-}"
        export EXPECT_VERBOSE="${EXPECT_VERBOSE:-0}"
        export CHECK_UPDATES_OUTPUT="${CHECK_UPDATES_OUTPUT:-}"
        export CHECK_UPDATES_STATUS="${CHECK_UPDATES_STATUS:-0}"
        export PACMAN_QUERY_STATUS="${PACMAN_QUERY_STATUS:-0}"
        export JJ_STUB_ROOT="$LAST_SOURCE"
        bash "${SCRIPT_ROOT}/dot_local/bin/executable_${wrapper}" "${args[@]}"
    ) > "$LAST_OUT" 2>&1; then
        LAST_STATUS=0
    else
        LAST_STATUS=$?
    fi
}

assert_czl_full_sequence() {
    local calls="$1"
    local source="$2"

    assert_contains "$calls" "CMD|chezmoi|args=source-path" "czl resolves selected source through helper"
    assert_contains "$calls" "diff -r @ --summary" "czl checks JJ clean state before mutation"
    assert_contains "$calls" "CMD|sudo|args=-v" "czl refreshes sudo credentials"
    assert_contains "$calls" "CMD|czuf|args=" "czl runs czuf"
    assert_contains "$calls" "CMD|pacman|args=-Syu --noconfirm" "czl updates pacman"
    assert_contains "$calls" "CMD|chezmoi-bump|args=--all --force" "czl runs pinned bump"
    assert_contains "$calls" "CMD|chezmoi|args=--source $source apply --refresh-externals --force" "czl applies selected source through chezmoi"
    assert_contains "$calls" "CHEZMOI_DIR=$source" "bumped/selected source exported"
    assert_order "$calls" "diff -r @ --summary" "CMD|czuf|args=" "clean-state check occurs before package updates"
}

assert_czm_full_shape() {
    local calls="$1"
    local source="$2"

    assert_contains "$calls" "CMD|chezmoi|args=source-path" "czm resolves selected source through helper"
    assert_contains "$calls" "diff -r @ --summary" "czm checks JJ clean state before mutation"
    assert_contains "$calls" "CMD|czuf|args=" "czm runs czuf"
    assert_contains "$calls" "CHEZMOI_MACOS_MAINTENANCE_MODE=1" "czm sets mac maintenance mode for czuf"
    assert_contains "$calls" "CMD|brew|args=update" "czm checks brew update"
    assert_contains "$calls" "CMD|brew|args=upgrade" "czm performs brew upgrade"
    assert_contains "$calls" "CMD|brew|args=upgrade --cask --greedy" "czm upgrades greedy casks"
    assert_contains "$calls" "CMD|chezmoi-bump|args=--all --force" "czm runs pinned bump"
    assert_contains "$calls" "CHEZMOI_DIR=$source" "bumped/selected source exported"
}

assert_plan_linux_calls() {
    local calls="$1"

    assert_contains "$calls" "CMD|jj-sync-trunk|args=--dry-run --no-fetch" "plan invokes dry-run trunk sync"
    assert_contains "$calls" " diff" "plan asks for chezmoi diff"
    assert_contains "$calls" "CMD|chezmoi-bump|args=--dry-run --all --force" "plan runs dry-run bump"

    if grep -Fq -- "CMD|checkupdates|" "$calls"; then
        pass "plan checks available updates via checkupdates"
    elif grep -Fq -- "CMD|pacman|args=-Qu" "$calls"; then
        pass "plan checks available updates via pacman -Qu"
    else
        fail "plan checks package updates via checkupdates or pacman -Qu"
    fi

    if grep -E "CMD\|chezmoi-bump\|" "$calls" | grep -Ev "--dry-run" >/dev/null 2>&1; then
        fail "plan never invokes non-dry-run chezmoi-bump"
    else
        pass "plan only uses dry-run bump"
    fi

    assert_not_contains "$calls" "CMD|czuf|args=" "plan does not run czuf"
    assert_not_contains "$calls" "CMD|sudo|" "plan does not refresh sudo"
    assert_not_contains "$calls" "CMD|pacman|args=-Syu" "plan does not perform pacman upgrade"
    assert_not_contains "$calls" "CMD|brew|args=update" "plan does not run brew update"
    assert_not_contains "$calls" "CMD|brew|args=upgrade" "plan does not run brew upgrade"
    assert_not_contains "$calls" "CMD|brew|args=cleanup" "plan does not run brew cleanup"
    assert_not_contains "$calls" " apply --refresh-externals --force" "plan does not apply pins"
}

assert_plan_darwin_calls() {
    local calls="$1"

    assert_contains "$calls" "CMD|jj-sync-trunk|args=--dry-run --no-fetch" "darwin plan invokes dry-run trunk sync"
    assert_contains "$calls" " diff" "darwin plan asks for chezmoi diff"
    assert_contains "$calls" "CMD|chezmoi-bump|args=--dry-run --all --force" "darwin plan runs dry-run bump"
    assert_contains "$calls" "CMD|brew|args=outdated --formula|HOMEBREW_NO_AUTO_UPDATE=1" "darwin plan calls brew outdated formula"
    assert_contains "$calls" "CMD|brew|args=outdated --cask|HOMEBREW_NO_AUTO_UPDATE=1" "darwin plan calls brew outdated cask"

    if grep -E "CMD\|chezmoi-bump\|" "$calls" | grep -Ev "--dry-run" >/dev/null 2>&1; then
        fail "darwin plan never invokes non-dry-run chezmoi-bump"
    else
        pass "darwin plan only uses dry-run bump"
    fi

    assert_not_contains "$calls" "CMD|czuf|args=" "darwin plan does not run czuf"
    assert_not_contains "$calls" "CMD|sudo|" "darwin plan does not refresh sudo"
    assert_not_contains "$calls" "CMD|brew|args=update" "darwin plan does not run brew update"
    assert_not_contains "$calls" "CMD|brew|args=upgrade" "darwin plan does not run brew upgrade"
    assert_not_contains "$calls" "CMD|brew|args=cleanup" "darwin plan does not run brew cleanup"
    assert_not_contains "$calls" " apply --refresh-externals --force" "darwin plan does not apply pins"
}

run_test() {
    local test_name="$1"
    local test_fn="$2"
    local before_failures="$FAIL_COUNT"

    printf '\n[TEST] %s\n' "$test_name"
    if "$test_fn"; then
        pass "$test_name"
    else
        if [ "$FAIL_COUNT" -eq "$before_failures" ]; then
            fail "$test_name"
        fi
    fi
    if [ -n "$TEST_FIXTURE_ROOT" ] && [ -d "$TEST_FIXTURE_ROOT" ]; then
        rm -rf "$TEST_FIXTURE_ROOT"
    fi
    TEST_FIXTURE_ROOT=""
}


test_czl_full_noarg_and_bump_pins() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czl "linux-gnu"
    assert_eq "$LAST_STATUS" "0" "czl no-arg exits successfully"
    assert_czl_full_sequence "$LAST_CALLS" "$LAST_SOURCE"

    run_wrapper "$fixture" czl "linux-gnu" --bump-pins
    assert_eq "$LAST_STATUS" "0" "czl --bump-pins exits successfully"
    assert_czl_full_sequence "$LAST_CALLS" "$LAST_SOURCE"
}

test_czl_conflicting_and_unknown_flags() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czl "linux-gnu" --bogus
    assert_eq "$LAST_STATUS" "2" "czl unknown flag exits with code 2"
    assert_not_contains "$LAST_OUT" "Command not found" "unknown flag fails at parser"

    run_wrapper "$fixture" czl "linux-gnu" --system-only --bump-pins
    assert_eq "$LAST_STATUS" "2" "czl --system-only conflicts with --bump-pins"
}

test_czl_full_rejects_dirty_source() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    JJ_DIFF_SUMMARY_PRE="M .chezmoidata.toml"

    run_wrapper "$fixture" czl "linux-gnu"
    assert_ne "$LAST_STATUS" "0" "czl full rejects dirty source before running mutation"
    assert_contains "$LAST_CALLS" "diff -r @ --summary" "czl checks diff summary before mutating"
    assert_contains "$LAST_OUT" "system-only" "dirty source failure suggests --system-only"

    assert_not_contains "$LAST_CALLS" "CMD|sudo|args=-v" "dirty source failure skips sudo"
    assert_not_contains "$LAST_CALLS" "CMD|czuf|args=" "dirty source failure skips czuf"
    assert_not_contains "$LAST_CALLS" "CMD|pacman|args=-Syu --noconfirm" "dirty source failure skips package updates"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi-bump|args=--all --force" "dirty source failure skips bump"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "dirty source failure skips final apply"
}

test_czl_system_only_allows_dirty_and_applies() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    JJ_DIFF_SUMMARY_PRE="M .chezmoidata.toml"

    run_wrapper "$fixture" czl "linux-gnu" --system-only
    assert_eq "$LAST_STATUS" "0" "czl --system-only is allowed on dirty source"
    assert_contains "$LAST_CALLS" "CMD|czuf|args=" "system-only path still converges externals"
    assert_contains "$LAST_CALLS" "CMD|pacman|args=-Syu --noconfirm" "system-only still performs pacman sync"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi-bump|args=--all --force" "system-only skips pinned-bump"
    assert_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "system-only still runs forced selected-source apply"
}

test_czl_plan_mode_nonmutating() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czl "linux-gnu" --plan
    assert_eq "$LAST_STATUS" "0" "czl --plan succeeds"
    assert_plan_linux_calls "$LAST_CALLS"
}

test_czl_plan_handles_checkupdates_statuses() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    CHECK_UPDATES_STATUS="2"
    run_wrapper "$fixture" czl "linux-gnu" --plan --system-only
    assert_eq "$LAST_STATUS" "0" "checkupdates no-update status 2 is nonfatal"

    CHECK_UPDATES_STATUS="5"
    run_wrapper "$fixture" czl "linux-gnu" --plan --system-only
    assert_eq "$LAST_STATUS" "5" "unexpected checkupdates failure propagates"
}

test_czl_plan_handles_pacman_query_statuses() {
    local fixture saved_original_path
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    rm -f "$fixture/bin/checkupdates"
    mkdir -p "$fixture/system-bin"
    ln -s "$(command -v bash)" "$fixture/system-bin/bash"
    saved_original_path="$ORIGINAL_PATH"
    ORIGINAL_PATH="$fixture/system-bin"

    PACMAN_QUERY_STATUS="1"
    run_wrapper "$fixture" czl "linux-gnu" --plan --system-only
    assert_eq "$LAST_STATUS" "0" "pacman -Qu no-update status 1 is nonfatal"

    PACMAN_QUERY_STATUS="5"
    run_wrapper "$fixture" czl "linux-gnu" --plan --system-only
    assert_eq "$LAST_STATUS" "5" "unexpected pacman -Qu failure propagates"

    ORIGINAL_PATH="$saved_original_path"
}

test_czm_full_noarg_and_bump_pins() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    CHEZMOI_BUMP_TOUCH="1"

    run_wrapper "$fixture" czm "darwin"
    assert_eq "$LAST_STATUS" "0" "czm no-arg exits successfully"
    assert_czm_full_shape "$LAST_CALLS" "$LAST_SOURCE"

    run_wrapper "$fixture" czm "darwin" --bump-pins
    assert_eq "$LAST_STATUS" "0" "czm --bump-pins exits successfully"
    assert_czm_full_shape "$LAST_CALLS" "$LAST_SOURCE"
}

test_czm_unknown_and_conflict_flags() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czm "darwin" --bogus
    assert_eq "$LAST_STATUS" "2" "czm unknown flag exits with code 2"

    run_wrapper "$fixture" czm "darwin" --system-only --bump-pins
    assert_eq "$LAST_STATUS" "2" "czm --system-only conflicts with --bump-pins"
}

test_czm_full_rejects_dirty_source() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    JJ_DIFF_SUMMARY_PRE="M dot_local/share/pi-cli/package.json"

    run_wrapper "$fixture" czm "darwin"
    assert_ne "$LAST_STATUS" "0" "czm full rejects dirty source before mutation"
    assert_contains "$LAST_CALLS" "diff -r @ --summary" "czm checks JJ summary"
    assert_contains "$LAST_OUT" "system-only" "czm dirty source failure suggests --system-only"
    assert_not_contains "$LAST_CALLS" "CMD|czuf|args=" "dirty source failure skips czuf"
    assert_not_contains "$LAST_CALLS" "CMD|brew|args=update" "dirty source failure skips brew update"
    assert_not_contains "$LAST_CALLS" "CMD|brew|args=upgrade" "dirty source failure skips brew upgrade"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi-bump|args=--all --force" "dirty source failure skips bump"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "dirty source failure skips final apply"
}

test_czm_system_only_allows_dirty_and_skips_bump() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    JJ_DIFF_SUMMARY_PRE="M dot_local/share/pi-cli/package.json"

    run_wrapper "$fixture" czm "darwin" --system-only
    assert_eq "$LAST_STATUS" "0" "czm --system-only is allowed on dirty source"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi-bump|args=--all --force" "czm system-only skips bump"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "czm system-only skips final apply"
    assert_contains "$LAST_CALLS" "CMD|brew|args=update" "system-only still performs brew update"
    assert_contains "$LAST_CALLS" "CMD|brew|args=upgrade" "system-only still performs brew upgrade"
}

test_czm_plan_mode_nonmutating() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czm "darwin" --plan
    assert_eq "$LAST_STATUS" "0" "czm --plan succeeds"
    assert_plan_darwin_calls "$LAST_CALLS"
}

test_czm_plan_system_only_skips_bump() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state

    run_wrapper "$fixture" czm "darwin" --plan --system-only
    assert_eq "$LAST_STATUS" "0" "czm --plan --system-only succeeds"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi-bump|args=--dry-run --all --force" "system-only disables bump in plan"
    assert_not_contains "$LAST_CALLS" " apply --refresh-externals --force" "plan system-only stays non-mutating"
}

test_czm_no_change_skips_apply_without_shasum() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    SHASUM_MODE="constant"

    run_wrapper "$fixture" czm "darwin"
    assert_eq "$LAST_STATUS" "0" "czm no-change full run exits successfully"
    assert_not_contains "$LAST_CALLS" "CMD|shasum" "no shasum-based fingerprinting"
    assert_not_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "unchanged bump skips final apply"
    assert_call_count_ge "$LAST_CALLS" "diff -r @ --summary" "2" "czm checks JJ summary after full bump pass"
}

test_czm_changed_summary_triggers_selected_apply() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    JJ_DIFF_SUMMARY_POST="M .chezmoidata.toml"

    run_wrapper "$fixture" czm "darwin"
    assert_eq "$LAST_STATUS" "0" "czm changed-jj summary full run exits successfully"
    assert_not_contains "$LAST_CALLS" "CMD|shasum" "changed run uses jj summary, not shasum"
    assert_contains "$LAST_CALLS" "diff -r @ --summary" "czm checks JJ summary during full maintenance"
    assert_call_count_ge "$LAST_CALLS" "diff -r @ --summary" "2" "czm checks pre and post-bump JJ summaries"
    assert_contains "$LAST_CALLS" "CMD|chezmoi|args=--source $LAST_SOURCE apply --refresh-externals --force" "changed jj summary triggers selected-source apply"
}

test_czm_cleanup_warning_nonfatal() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    BREW_CLEANUP_FAIL="1"

    run_wrapper "$fixture" czm "darwin"
    assert_eq "$LAST_STATUS" "0" "czm ignores non-fatal brew cleanup failure"
    assert_contains "$LAST_CALLS" "CMD|brew|args=cleanup" "cleanup is attempted"
    assert_contains "$LAST_OUT" "warning" "cleanup warning is emitted to output"
}

test_verbose_sets_verbosity_context() {
    local fixture
    fixture="$(mktemp -d)"
    TEST_FIXTURE_ROOT="$fixture"
    create_fixture "$fixture"
    reset_test_state
    EXPECT_VERBOSE="1"

    run_wrapper "$fixture" czl "linux-gnu" --plan --verbose
    assert_eq "$LAST_STATUS" "0" "czl --plan --verbose succeeds"
    assert_contains "$LAST_CALLS" "--remote origin|VERBOSE=true" "verbose sets VERBOSE=true for sync and trace output"

    run_wrapper "$fixture" czm "darwin" --plan --verbose
    assert_eq "$LAST_STATUS" "0" "czm --plan --verbose succeeds"
    assert_contains "$LAST_CALLS" "--remote origin|VERBOSE=true" "verbose sets VERBOSE=true for darwin plan"
}

run_test "czl no-arg and --bump-pins" test_czl_full_noarg_and_bump_pins
run_test "czl unknown/conflicting flags" test_czl_conflicting_and_unknown_flags
run_test "czl dirty source rejects before mutation" test_czl_full_rejects_dirty_source
run_test "czl system-only allows dirty and still applies" test_czl_system_only_allows_dirty_and_applies
run_test "czl --plan non-mutating" test_czl_plan_mode_nonmutating
run_test "czl --plan checkupdates statuses" test_czl_plan_handles_checkupdates_statuses
run_test "czl --plan pacman query statuses" test_czl_plan_handles_pacman_query_statuses
run_test "czm no-arg and --bump-pins" test_czm_full_noarg_and_bump_pins
run_test "czm unknown/conflicting flags" test_czm_unknown_and_conflict_flags
run_test "czm dirty source rejects before mutation" test_czm_full_rejects_dirty_source
run_test "czm system-only skips bump on dirty" test_czm_system_only_allows_dirty_and_skips_bump
run_test "czm --plan non-mutating" test_czm_plan_mode_nonmutating
run_test "czm --plan --system-only disables bump" test_czm_plan_system_only_skips_bump
run_test "czm no-change skips final apply" test_czm_no_change_skips_apply_without_shasum
run_test "czm changed summary triggers apply" test_czm_changed_summary_triggers_selected_apply
run_test "czm cleanup warning is nonfatal" test_czm_cleanup_warning_nonfatal
run_test "--verbose sets VERBOSE=true and trace" test_verbose_sets_verbosity_context

printf '\nTests passed: %s\n' "$PASS_COUNT"
printf 'Tests failed: %s\n' "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
