#!/usr/bin/env bash
set -uo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_ROOT/dot_local/private_lib/chezmoi-update-helpers.sh"
# shellcheck disable=SC1091
. "$SCRIPT_ROOT/tests/lib/temp.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TEST_FIXTURE_ROOT=""
# Fixtures replace PATH, so find the real tools before any test runs.
REAL_JJ="$(command -v jj 2>/dev/null || true)"
REAL_GIT="$(command -v git 2>/dev/null || true)"

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '[PASS] %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '[FAIL] %s\n' "$1"
    return 1
}

expect_eq() {
    local actual="$1" expected="$2" message="$3"
    [ "$actual" = "$expected" ] && return 0
    fail "$message (got=$actual expected=$expected)"
}

expect_contains() {
    local file="$1" expected="$2" message="$3"
    [ -f "$file" ] && grep -Fq -- "$expected" "$file" && return 0
    fail "$message"
}

expect_not_contains() {
    local file="$1" expected="$2" message="$3"
    [ -f "$file" ] && ! grep -Fq -- "$expected" "$file" && return 0
    fail "$message"
}

make_fixture() {
    local root="$1"
    mkdir -p "$root/bin" "$root/repo/.jj" "$root/other/.jj" "$root/non-jj"
    printf '[git]\ndefaultBranch = "legacy"\n' > "$root/repo/.chezmoidata.toml"
    printf '[git]\ndefaultBranch = "other"\n' > "$root/other/.chezmoidata.toml"
    printf '[git]\ndefaultBranch = "missing-jj"\n' > "$root/non-jj/.chezmoidata.toml"
    : > "$root/calls.log"

    cat > "$root/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'chezmoi cwd=%s args=%s\n' "$PWD" "$*" >> "$TEST_CALL_LOG"
if [ "${CHEZMOI_STUB_STATUS:-0}" -ne 0 ]; then
    echo "stub source-path failure" >&2
    exit "$CHEZMOI_STUB_STATUS"
fi
if [ "$*" = "source-path" ]; then
    printf '%s\n' "$CHEZMOI_STUB_SOURCE"
    exit 0
fi
exit "${CHEZMOI_STUB_COMMAND_STATUS:-0}"
STUB

    cat > "$root/bin/jj" <<'STUB'
#!/usr/bin/env bash
printf 'jj cwd=%s args=%s\n' "$PWD" "$*" >> "$TEST_CALL_LOG"
case " $* " in
    *" root "*)
        if [ "${JJ_STUB_ROOT_STATUS:-0}" -ne 0 ]; then
            echo "stub not a jj repo" >&2
            exit "$JJ_STUB_ROOT_STATUS"
        fi
        printf '%s\n' "${JJ_STUB_ROOT:-$PWD}"
        ;;
    *" rebase "*) exit "${JJ_STUB_REBASE_STATUS:-0}" ;;
    *) exit 0 ;;
esac
STUB

    cat > "$root/bin/jj-sync-trunk" <<'STUB'
#!/usr/bin/env bash
printf 'jj-sync-trunk cwd=%s args=%s\n' "$PWD" "$*" >> "$TEST_CALL_LOG"
exit "${JJ_SYNC_STUB_STATUS:-0}"
STUB

    chmod +x "$root/bin/chezmoi" "$root/bin/jj" "$root/bin/jj-sync-trunk"
}

reset_helper_state() {
    unset CHEZMOI_SOURCE_DIR CHEZMOI_DIR CHEZMOI_SOURCE_DIR_RESOLVED CHEZMOI_SOURCE_DIR_RESOLVED_VALID
    unset CHEZMOI_JJ_REMOTE JJ_REMOTE VERBOSE
    unset CHEZMOI_STUB_STATUS CHEZMOI_STUB_COMMAND_STATUS JJ_STUB_ROOT_STATUS JJ_STUB_REBASE_STATUS JJ_SYNC_STUB_STATUS
}

with_fixture_env() {
    local root="$1"
    export HOME="$root"
    export PATH="$root/bin:/usr/bin:/bin"
    export TEST_CALL_LOG="$root/calls.log"
    export CHEZMOI_STUB_SOURCE="$root/repo"
    export JJ_STUB_ROOT="$root/repo"
}

test_explicit_source_and_exports() {
    local root canonical
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"

    resolve_chezmoi_source_dir || return 1
    canonical="$(cd "$root/repo" && pwd -P)"
    expect_eq "$CHEZMOI_SOURCE_DIR" "$canonical" "CHEZMOI_SOURCE_DIR canonicalized" || return 1
    expect_eq "$CHEZMOI_DIR" "$canonical" "CHEZMOI_DIR mirrors source" || return 1
    expect_eq "$(chezmoi_source_dir)" "$canonical" "chezmoi_source_dir prints canonical source" || return 1
}

test_chezmoi_dir_compatibility() {
    local root
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_DIR="$root/repo"

    resolve_chezmoi_source_dir || return 1
    expect_eq "$CHEZMOI_SOURCE_DIR" "$(cd "$root/repo" && pwd -P)" "CHEZMOI_DIR remains a supported override" || return 1
}

test_untrusted_cached_value_cannot_bypass_validation() {
    local root
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR_RESOLVED="relative/injected"
    export CHEZMOI_SOURCE_DIR="$root/repo"

    resolve_chezmoi_source_dir || return 1
    expect_eq "$CHEZMOI_SOURCE_DIR_RESOLVED" "$(cd "$root/repo" && pwd -P)" "Untrusted cached value cannot bypass source validation" || return 1
}

test_conflicting_overrides_fail() {
    local root status
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"
    export CHEZMOI_DIR="$root/other"

    if resolve_chezmoi_source_dir >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "Conflicting source overrides fail"; return 1; }
    expect_contains "$root/err" "conflict" "Conflict error is actionable" || return 1
}

test_invalid_paths_fail_closed() {
    local root status
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="relative/repo"
    if resolve_chezmoi_source_dir >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "Relative source path fails"; return 1; }

    reset_helper_state
    with_fixture_env "$root"
    mkdir -p "$root/missing-data/.jj"
    export CHEZMOI_SOURCE_DIR="$root/missing-data"
    if resolve_chezmoi_source_dir >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "Source without .chezmoidata.toml fails"; return 1; }

    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/non-jj"
    export JJ_STUB_ROOT_STATUS=1
    if resolve_chezmoi_source_dir >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "Non-JJ source path fails"; return 1; }
}

test_source_path_fallback_and_failure() {
    local root status
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"

    resolve_chezmoi_source_dir || return 1
    expect_eq "$CHEZMOI_SOURCE_DIR" "$(cd "$root/repo" && pwd -P)" "chezmoi source-path is used without overrides" || return 1
    expect_contains "$root/calls.log" "args=source-path" "chezmoi source-path was called" || return 1

    : > "$root/calls.log"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_STUB_STATUS=1
    if resolve_chezmoi_source_dir >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "source-path failure fails closed"; return 1; }
    expect_contains "$root/err" "source-path" "source-path failure is actionable" || return 1
}

test_prepare_uses_sync_then_trunk_rebase() {
    local root snapshot_line sync_line rebase_line update_line
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"

    chezmoi_prepare_jj_update || return 1
    expect_contains "$root/calls.log" "jj cwd=$root/repo args=--quiet -R $root/repo util snapshot" "prepare snapshots local edits" || return 1
    expect_contains "$root/calls.log" "jj-sync-trunk cwd=$root/repo args=--remote origin" "prepare invokes jj-sync-trunk in selected repo" || return 1
    expect_contains "$root/calls.log" "jj cwd=$root/repo args=--quiet --ignore-working-copy -R $root/repo rebase -d trunk()" "prepare quietly rebases onto trunk() without touching files" || return 1
    expect_contains "$root/calls.log" "jj cwd=$root/repo args=--quiet -R $root/repo workspace update-stale" "prepare then updates the files" || return 1
    expect_not_contains "$root/calls.log" "git fetch" "prepare does not duplicate fetch" || return 1
    snapshot_line="$(grep -n ' util snapshot' "$root/calls.log" | cut -d: -f1)"
    sync_line="$(grep -n 'jj-sync-trunk' "$root/calls.log" | cut -d: -f1)"
    rebase_line="$(grep -n ' rebase ' "$root/calls.log" | cut -d: -f1)"
    update_line="$(grep -n ' update-stale' "$root/calls.log" | cut -d: -f1)"
    [ "$snapshot_line" -lt "$sync_line" ] || { fail "snapshot runs before sync"; return 1; }
    [ "$sync_line" -lt "$rebase_line" ] || { fail "sync runs before rebase"; return 1; }
    [ "$rebase_line" -lt "$update_line" ] || { fail "rebase runs before the file update"; return 1; }
}

test_prepare_selected_remote() {
    local root
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"
    export CHEZMOI_JJ_REMOTE="upstream"

    chezmoi_prepare_jj_update || return 1
    expect_contains "$root/calls.log" "jj-sync-trunk cwd=$root/repo args=--remote upstream" "prepare passes selected remote" || return 1
}

test_chezmoi_commands_use_selected_source() {
    local root
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"

    run_chezmoi_with_source apply --dry-run || return 1
    expect_contains "$root/calls.log" "args=--source $root/repo apply --dry-run" "selected source is passed to chezmoi" || return 1
}

test_duplicate_source_argument_is_rejected() {
    local root status
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"

    if run_chezmoi_with_source apply --source "$root/other" >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    [ "$status" -ne 0 ] || { fail "Duplicate --source is rejected"; return 1; }
    expect_contains "$root/err" "CHEZMOI_SOURCE_DIR" "Duplicate source error explains the supported override" || return 1
    expect_not_contains "$root/calls.log" "apply --source" "Rejected duplicate source does not invoke chezmoi apply" || return 1
}

test_prepare_failures_propagate() {
    local root status
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    make_fixture "$root"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"
    export JJ_SYNC_STUB_STATUS=7

    if chezmoi_prepare_jj_update >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    expect_eq "$status" "7" "sync failure status propagates" || return 1
    expect_not_contains "$root/calls.log" " rebase " "sync failure stops before rebase" || return 1

    : > "$root/calls.log"
    reset_helper_state
    with_fixture_env "$root"
    export CHEZMOI_SOURCE_DIR="$root/repo"
    export JJ_STUB_REBASE_STATUS=8
    if chezmoi_prepare_jj_update >"$root/out" 2>"$root/err"; then status=0; else status=$?; fi
    expect_eq "$status" "8" "rebase failure status propagates" || return 1
}

# A remote that rewrites trunk history makes the fetch move @ onto root().
# Real jj must keep the tracked files on disk and keep ignored files out of @,
# with and without the managed snapshot.auto-update-stale setting.
check_prepare_after_trunk_rewrite() {
    local case_dir="$1" auto_update_stale="$2" repo changes label="auto-update-stale=$2"
    mkdir -p "$case_dir"
    export JJ_CONFIG="$case_dir/jj.toml"
    printf '[user]\nname = "Test"\nemail = "test@example.com"\n[snapshot]\nauto-update-stale = %s\n' \
        "$auto_update_stale" > "$JJ_CONFIG"

    git init -q --bare "$case_dir/remote.git" || return 1
    git init -q "$case_dir/seed" || return 1
    printf 'ignored/\n' > "$case_dir/seed/.gitignore"
    printf 'tracked\n' > "$case_dir/seed/tracked.txt"
    : > "$case_dir/seed/.chezmoidata.toml"
    git -C "$case_dir/seed" add -A && git -C "$case_dir/seed" commit -qm first || return 1
    git -C "$case_dir/seed" push -q "file://$case_dir/remote.git" master || return 1
    jj git clone --quiet --colocate "file://$case_dir/remote.git" "$case_dir/repo" 2>/dev/null || return 1
    repo="$case_dir/repo"
    jj --quiet -R "$repo" new 'master@origin' || return 1
    mkdir "$repo/ignored" && printf 'local\n' > "$repo/ignored/cache.txt"
    printf 'edited\n' > "$repo/tracked.txt"

    git -C "$case_dir/seed" checkout -q --orphan rewritten && git -C "$case_dir/seed" commit -qm rewritten || return 1
    git -C "$case_dir/seed" push -q -f "file://$case_dir/remote.git" rewritten:master || return 1

    reset_helper_state
    export CHEZMOI_SOURCE_DIR="$repo"
    if ! chezmoi_prepare_jj_update >"$case_dir/out" 2>"$case_dir/err"; then
        cat "$case_dir/err"
        fail "$label: prepare succeeds after a trunk rewrite"
        return 1
    fi
    changes="$(cd "$repo" && jj diff -r @ --summary)"
    expect_eq "$changes" "M tracked.txt" "$label: only the local edit stays in @" || return 1
    expect_eq "$(jj -R "$repo" log -r '@- & trunk()' --no-graph -T '"on-trunk"')" "on-trunk" \
        "$label: @ moves onto the rewritten trunk" || return 1
    [ -f "$repo/.gitignore" ] || { fail "$label: .gitignore stays on disk"; return 1; }
    expect_contains "$case_dir/err" "history was rewritten" "$label: prepare warns about the rewritten trunk" || return 1
}

test_prepare_survives_rewritten_trunk() {
    local root
    if [ -z "$REAL_JJ" ] || [ -z "$REAL_GIT" ]; then
        printf 'jj and git are required\n'
        return 77
    fi
    new_test_temp_dir root
    TEST_FIXTURE_ROOT="$root"
    reset_helper_state
    mkdir -p "$root/bin"
    # Git keeps source scripts at mode 644, so run this one through bash.
    printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' \
        "$SCRIPT_ROOT/dot_local/bin/executable_jj-sync-trunk" > "$root/bin/jj-sync-trunk"
    chmod +x "$root/bin/jj-sync-trunk"
    export HOME="$root"
    export PATH="$root/bin:${REAL_JJ%/*}:${REAL_GIT%/*}:/usr/bin:/bin"
    export GIT_CONFIG_GLOBAL="$root/gitconfig"
    printf '[user]\n\tname = Test\n\temail = test@example.com\n[init]\n\tdefaultBranch = master\n' > "$GIT_CONFIG_GLOBAL"

    check_prepare_after_trunk_rewrite "$root/stale-on" true || return 1
    check_prepare_after_trunk_rewrite "$root/stale-off" false || return 1
}

run_test() {
    local name="$1" fn="$2" before_failures status
    printf '[TEST] %s\n' "$name"
    TEST_FIXTURE_ROOT=""
    before_failures="$FAIL_COUNT"
    status=0
    "$fn" || status=$?
    if [ "$status" -eq 0 ]; then
        pass "$name"
    elif [ "$status" -eq 77 ]; then
        SKIP_COUNT=$((SKIP_COUNT + 1))
        printf '[SKIP] %s\n' "$name"
    else
        if [ "$FAIL_COUNT" -eq "$before_failures" ]; then
            FAIL_COUNT=$((FAIL_COUNT + 1))
            printf '[FAIL] %s\n' "$name"
        fi
    fi
    if [ -n "$TEST_FIXTURE_ROOT" ]; then
        remove_test_temp_dir "$TEST_FIXTURE_ROOT" || FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_test "explicit source and exports" test_explicit_source_and_exports
run_test "CHEZMOI_DIR compatibility" test_chezmoi_dir_compatibility
run_test "untrusted cached value" test_untrusted_cached_value_cannot_bypass_validation
run_test "conflicting overrides" test_conflicting_overrides_fail
run_test "invalid paths fail closed" test_invalid_paths_fail_closed
run_test "source-path fallback and failure" test_source_path_fallback_and_failure
run_test "sync then trunk rebase" test_prepare_uses_sync_then_trunk_rebase
run_test "selected remote" test_prepare_selected_remote
run_test "chezmoi commands use selected source" test_chezmoi_commands_use_selected_source
run_test "duplicate source argument" test_duplicate_source_argument_is_rejected
run_test "failure propagation" test_prepare_failures_propagate
run_test "rewritten trunk" test_prepare_survives_rewritten_trunk

printf '\nTests passed: %s\nFailures: %s\nSkipped: %s\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
[ "$SKIP_COUNT" -eq 0 ] || exit 77
