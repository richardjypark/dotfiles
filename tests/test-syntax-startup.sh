#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
. "$REPO_ROOT/tests/lib/temp.sh"
new_test_temp_dir TMP_DIR
trap 'remove_test_temp_dir "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/tests/lib"
cp "$REPO_ROOT/tests/lib/shell-files.sh" "$TMP_DIR/tests/lib/shell-files.sh"
git -C "$TMP_DIR" init -q

printf '%s\n' 'if [[ ]]' > "$TMP_DIR/dot_zshenv"
printf '%s\n' 'if [[ ]]' > "$TMP_DIR/dot_zshrc.tmpl"

for bad_file in dot_zshenv dot_zshrc.tmpl; do
    printf '%s\n' 'true' > "$TMP_DIR/dot_zshenv"
    printf '%s\n' 'true' > "$TMP_DIR/dot_zshrc.tmpl"
    printf '%s\n' 'if [[' > "$TMP_DIR/$bad_file"
    if TEST_REPO_ROOT="$TMP_DIR" "$REPO_ROOT/tests/syntax" > "$TMP_DIR/result" 2>&1; then
        printf '[FAIL] invalid %s passed the syntax suite\n' "$bad_file" >&2
        exit 1
    fi
    if ! grep -Fq "[FAIL] $bad_file" "$TMP_DIR/result"; then
        cat "$TMP_DIR/result" >&2
        printf '[FAIL] invalid %s was not found by the syntax suite\n' "$bad_file" >&2
        exit 1
    fi
done

printf '[PASS] both startup files fail on invalid syntax\n'
