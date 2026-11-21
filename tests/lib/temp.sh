# shellcheck shell=bash

TEST_TEMP_BASE="$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P)" || TEST_TEMP_BASE=""

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
