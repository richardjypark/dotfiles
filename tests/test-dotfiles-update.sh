#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_ROOT/tests/lib/temp.sh"
new_test_temp_dir UPDATE_TEST_ROOT
trap 'remove_test_temp_dir "$UPDATE_TEST_ROOT"' EXIT

mkdir -p "$UPDATE_TEST_ROOT/bin" "$UPDATE_TEST_ROOT/repo/.jj" \
    "$UPDATE_TEST_ROOT/other/.jj" "$UPDATE_TEST_ROOT/home/.local/lib/chezmoi" \
    "$UPDATE_TEST_ROOT/home/.local/share/omarchy" "$UPDATE_TEST_ROOT/backups"
cp "$SCRIPT_ROOT/dot_local/private_lib/chezmoi-update-helpers.sh" \
    "$UPDATE_TEST_ROOT/home/.local/lib/chezmoi-update-helpers.sh"
cp "$SCRIPT_ROOT/dot_local/private_lib/chezmoi/npm.sh" \
    "$UPDATE_TEST_ROOT/home/.local/lib/chezmoi/npm.sh"
printf 'profile = "omarchy"\n' > "$UPDATE_TEST_ROOT/repo/.chezmoidata.toml"
cp "$UPDATE_TEST_ROOT/repo/.chezmoidata.toml" "$UPDATE_TEST_ROOT/other/.chezmoidata.toml"

cat > "$UPDATE_TEST_ROOT/bin/jj" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'jj %s\n' "$*" >> "$UPDATE_CALL_LOG"
repo=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ignore-working-copy|--quiet) shift ;;
        -R) repo="$2"; shift 2 ;;
        *) break ;;
    esac
done
case "$1" in
    root) printf '%s\n' "$repo" ;;
    diff)
        if [ "$2" = --from ]; then printf '%s' "${UPDATE_UNMERGED:-}"
        else printf '%s' "${UPDATE_DIRTY:-}"; fi
        ;;
    log)
        if [[ " $* " == *' conflicts() & @ '* ]]; then printf '%s' "${UPDATE_CONFLICTS:-}"
        else printf '%s' "${UPDATE_DESCRIPTION-chore: saved source history}"; fi
        ;;
    status) : ;;
    describe) exit "${UPDATE_DESCRIBE_STATUS:-0}" ;;
    *) printf 'Unexpected JJ mutation\n' >&2; exit 90 ;;
esac
STUB
cat > "$UPDATE_TEST_ROOT/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'chezmoi %s\n' "$*" >> "$UPDATE_CALL_LOG"
if [ "$1" = source-path ]; then
    printf '%s\n' "$UPDATE_DEFAULT_SOURCE"
elif [ "$1" = --source ] && [ "$3" = data ]; then
    printf '{"profile":"%s"}\n' "${UPDATE_SAVED_PROFILE:-omarchy}"
else
    printf 'Unexpected chezmoi mutation\n' >&2
    exit 90
fi
STUB
cat > "$UPDATE_TEST_ROOT/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$UPDATE_CALL_LOG"
[ "$1" = -C ] && [ "$3" = bundle ] && [ "$4" = create ] && [ "$6" = --all ] || exit 90
if [ "${UPDATE_BACKUP_STATUS:-0}" -ne 0 ]; then exit "$UPDATE_BACKUP_STATUS"; fi
printf 'private test bundle\n' > "$5"
printf '%s\n' "$5" > "$UPDATE_BUNDLE_PATH"
STUB
cat > "$UPDATE_TEST_ROOT/bin/omarchy" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >> "$UPDATE_CALL_LOG"
[ "$*" = update ] || exit 90
if [ "${UPDATE_CANCELED:-0}" = 1 ]; then printf 'Update cancelled\n'; fi
exit "${UPDATE_OMARCHY_STATUS:-0}"
STUB
cat > "$UPDATE_TEST_ROOT/bin/czu" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'czu %s source=%s legacy=%s profile=%s trust=%s force=%s\n' \
    "$*" "$CHEZMOI_SOURCE_DIR" "$CHEZMOI_DIR" "$CHEZMOI_PROFILE" \
    "${TRUST_ON_FIRST_USE_INSTALLERS:-}" "${CHEZMOI_FORCE_UPDATE:-}" >> "$UPDATE_CALL_LOG"
exit "${UPDATE_CZU_STATUS:-0}"
STUB
cat > "$UPDATE_TEST_ROOT/bin/id" <<'STUB'
#!/usr/bin/env bash
[ "$*" = -u ] || exit 90
printf '%s\n' "${UPDATE_USER_ID:-1000}"
STUB
chmod +x "$UPDATE_TEST_ROOT/bin/"*

export HOME="$UPDATE_TEST_ROOT/home"
export PATH="$UPDATE_TEST_ROOT/bin:/usr/bin:/bin"
export TMPDIR="$UPDATE_TEST_ROOT/backups"
export UPDATE_CALL_LOG="$UPDATE_TEST_ROOT/calls.log"
export UPDATE_DEFAULT_SOURCE="$UPDATE_TEST_ROOT/repo"
export UPDATE_BUNDLE_PATH="$UPDATE_TEST_ROOT/bundle-path"
unset CHEZMOI_SOURCE_DIR CHEZMOI_DIR CHEZMOI_PROFILE

reset_case() {
    : > "$UPDATE_CALL_LOG"
    unset UPDATE_DIRTY UPDATE_DESCRIPTION UPDATE_BACKUP_STATUS UPDATE_OMARCHY_STATUS UPDATE_DESCRIBE_STATUS
    unset UPDATE_UNMERGED UPDATE_CONFLICTS
    unset UPDATE_CZU_STATUS UPDATE_CANCELED UPDATE_USER_ID UPDATE_SAVED_PROFILE
    unset CHEZMOI_SOURCE_DIR CHEZMOI_DIR CHEZMOI_PROFILE CHEZMOI_FORCE_UPDATE
    export TMPDIR="$UPDATE_TEST_ROOT/backups"
}

run_update() {
    UPDATE_STATUS=0
    bash "$SCRIPT_ROOT/dot_local/bin/executable_dotfiles-update" "$@" \
        > "$UPDATE_TEST_ROOT/output" 2>&1 || UPDATE_STATUS=$?
}

assert_contains() {
    if ! rg -q -F -- "$2" "$1"; then
        printf '[FAIL] %s\n' "$3" >&2
        cat "$UPDATE_TEST_ROOT/output" >&2
        exit 1
    fi
}

assert_no_updates() {
    if rg -q '^(git|omarchy|czu) ' "$UPDATE_CALL_LOG"; then
        printf '[FAIL] %s\n' "$1" >&2
        exit 1
    fi
}

reset_case
export UPDATE_DIRTY='M tracked-source'
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'dirty source stops before backup and updates'
printf '[PASS] Dirty source stops before backup and updates\n'

reset_case
export UPDATE_UNMERGED='M unmerged-source'
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'unmerged committed source stops before backup and updates'
printf '[PASS] Unmerged committed source stops before backup and updates\n'

reset_case
export UPDATE_CONFLICTS=conflicted-commit
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'conflicted source stops before backup and updates'
printf '[PASS] Conflicted source stops before backup and updates\n'

reset_case
export UPDATE_DESCRIPTION=""
run_update
[ "$UPDATE_STATUS" -eq 0 ]
assert_contains "$UPDATE_CALL_LOG" 'describe -m chore: prepare routine updates' 'blank clean change gets a conventional description'
python3 - "$UPDATE_CALL_LOG" <<'PY'
import sys
from pathlib import Path
calls = Path(sys.argv[1]).read_text().splitlines()
describe = next(i for i, line in enumerate(calls) if ' describe ' in line)
backup = next(i for i, line in enumerate(calls) if line.startswith('git '))
assert describe < backup
PY
printf '[PASS] Blank clean source is described before the history backup\n'

reset_case
export UPDATE_DESCRIPTION="" UPDATE_DESCRIBE_STATUS=19
run_update
[ "$UPDATE_STATUS" -eq 19 ]
assert_no_updates 'description failure stops before backup and updates'
printf '[PASS] Description failure stops updates\n'

reset_case
export UPDATE_BACKUP_STATUS=17
run_update
[ "$UPDATE_STATUS" -ne 0 ]
if rg -q '^(omarchy|czu) ' "$UPDATE_CALL_LOG"; then exit 1; fi
assert_contains "$UPDATE_TEST_ROOT/output" 'history backup failed' 'backup error is clear'
printf '[PASS] Backup failure stops updates\n'

reset_case
export UPDATE_OMARCHY_STATUS=23
run_update
[ "$UPDATE_STATUS" -eq 23 ]
if rg -q '^czu ' "$UPDATE_CALL_LOG"; then exit 1; fi
printf '[PASS] Omarchy failure stops reviewed apply and keeps its status\n'

reset_case
export CHEZMOI_SOURCE_DIR="$UPDATE_TEST_ROOT/other"
export CHEZMOI_FORCE_UPDATE=1
run_update
[ "$UPDATE_STATUS" -eq 0 ]
assert_contains "$UPDATE_CALL_LOG" "chezmoi --source $UPDATE_TEST_ROOT/other data --format=json" 'saved profile uses selected source'
assert_contains "$UPDATE_CALL_LOG" "git -C $UPDATE_TEST_ROOT/other bundle create" 'backup uses selected source'
assert_contains "$UPDATE_CALL_LOG" "czu --reviewed source=$UPDATE_TEST_ROOT/other legacy=$UPDATE_TEST_ROOT/other profile=omarchy trust=1 force=" 'apply has selected source, trust, and no force'
python3 - "$UPDATE_CALL_LOG" "$UPDATE_BUNDLE_PATH" "$UPDATE_TEST_ROOT/other" <<'PY'
import stat, sys
from pathlib import Path
calls = Path(sys.argv[1]).read_text().splitlines()
positions = [next(i for i, line in enumerate(calls) if line.startswith(prefix)) for prefix in ('git ', 'omarchy ', 'czu ')]
assert positions == sorted(positions)
assert not any(' describe ' in line for line in calls)
backup = Path(Path(sys.argv[2]).read_text().strip())
assert not backup.is_relative_to(Path(sys.argv[3]))
assert stat.S_IMODE(backup.stat().st_mode) == 0o600
assert stat.S_IMODE(backup.parent.stat().st_mode) == 0o700
PY
assert_contains "$UPDATE_TEST_ROOT/output" 'Defer any Omarchy reboot' 'reboot instruction is visible'
printf '[PASS] Private external backup precedes native update and reviewed selected-source apply\n'

reset_case
export UPDATE_CANCELED=1
run_update
[ "$UPDATE_STATUS" -eq 0 ]
assert_contains "$UPDATE_CALL_LOG" 'czu --reviewed' 'reviewed source can apply after native cancellation'
assert_contains "$UPDATE_TEST_ROOT/output" 'This also runs if Omarchy was canceled' 'cancellation is not reported as system update success'
printf '[PASS] Native cancellation does not falsely claim system packages changed\n'

reset_case
export UPDATE_CZU_STATUS=31
run_update
[ "$UPDATE_STATUS" -eq 31 ]
if rg -q -F 'Reviewed dotfiles update completed' "$UPDATE_TEST_ROOT/output"; then exit 1; fi
printf '[PASS] Reviewed apply failure is returned without a completion message\n'

reset_case
export TMPDIR="$UPDATE_TEST_ROOT/repo"
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'backup location inside source is rejected'
printf '[PASS] Backup path inside source is rejected\n'

reset_case
export UPDATE_SAVED_PROFILE=standard
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'saved standard profile stops before updates'
printf '[PASS] Saved standard profile is respected\n'

reset_case
export UPDATE_USER_ID=0
run_update
[ "$UPDATE_STATUS" -ne 0 ]
assert_no_updates 'root invocation stops before updates'
printf '[PASS] Root invocation is rejected\n'

reset_case
run_update --force
[ "$UPDATE_STATUS" -eq 2 ]
assert_no_updates 'unexpected arguments stop updates'
printf '[PASS] Unexpected arguments are rejected\n'
