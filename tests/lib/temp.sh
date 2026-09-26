# shellcheck shell=bash
# Temporary directories for repository tests.
#
# Create and remove test directories only through these helpers. A failed
# mktemp stops the test process: it must never fall back to the caller's
# directory, which can be this repository or $HOME. The explicit template
# honors TMPDIR, which macOS mktemp ignores without a template.

TEST_TEMP_BASE="$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P)" || TEST_TEMP_BASE=""

# new_test_temp_dir NAME: create a private directory and store its path in the
# variable NAME. Call it directly, not in $(...), so a failure exits the test.
new_test_temp_dir() {
    local _test_temp_dir
    if [ -z "$TEST_TEMP_BASE" ] || [ "$TEST_TEMP_BASE" = / ]; then
        printf 'FATAL: TMPDIR is not a usable directory: %s\n' "${TMPDIR:-/tmp}" >&2
        exit 70
    fi
    if ! _test_temp_dir="$(mktemp -d "$TEST_TEMP_BASE/chezmoi-test.XXXXXXXX")" || [ ! -d "$_test_temp_dir" ]; then
        printf 'FATAL: cannot create a temporary directory in %s\n' "$TEST_TEMP_BASE" >&2
        exit 70
    fi
    printf -v "$1" '%s' "$_test_temp_dir"
}

# remove_test_temp_dir PATH: remove a directory made by new_test_temp_dir.
# Refuse every other path so an empty or wrong value cannot delete real data.
remove_test_temp_dir() {
    local path="${1:-}" name
    [ -n "$path" ] || return 0
    name="${path#"$TEST_TEMP_BASE"/chezmoi-test.}"
    if [ -z "$TEST_TEMP_BASE" ] || [ "$TEST_TEMP_BASE" = / ] || [ "$name" = "$path" ] \
        || [ -z "$name" ] || [[ "$name" == */* || "$name" == .* ]]; then
        printf 'Refusing to remove a path outside the test temporary directory: %s\n' "$path" >&2
        return 1
    fi
    rm -rf -- "$path"
}
