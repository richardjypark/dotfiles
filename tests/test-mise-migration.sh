#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
. "$REPO_ROOT/tests/lib/temp.sh"
new_test_temp_dir TEST_DIR
trap 'remove_test_temp_dir "$TEST_DIR"' EXIT
export HOME="$TEST_DIR/home"
export STATE_DIR="$TEST_DIR/state"
mkdir -p "$HOME" "$TEST_DIR/bin"

printf '#!/usr/bin/env sh\nprintf "11.9.0\\n"\n' > "$TEST_DIR/bin/npm"
chmod +x "$TEST_DIR/bin/npm"
export TEST_MISE_NPM="$TEST_DIR/bin/npm"

mise() {
    if [ "$*" = "which npm" ]; then
        printf '%s\n' "$TEST_MISE_NPM"
        return 0
    fi
    return 1
}

# shellcheck disable=SC1091
. "$REPO_ROOT/dot_local/private_lib/chezmoi-helpers.sh"
NPM_CMD=""
[ "$(resolve_npm_cmd)" = "$TEST_MISE_NPM" ]

# The update helpers return the same global npm path, not a project-local one.
# shellcheck disable=SC1091
. "$REPO_ROOT/dot_local/private_lib/chezmoi-update-helpers.sh"
[ "$(resolve_npm_cmd)" = "$TEST_MISE_NPM" ]
grep -Fq '"CHEZMOI_ROLE=server"' "$REPO_ROOT/bootstrap-vps.sh"

if command -v chezmoi >/dev/null 2>&1; then
    workstation_ignore="$(chezmoi --source "$REPO_ROOT" execute-template < "$REPO_ROOT/.chezmoiignore")"
    [[ "$workstation_ignore" != *'.chezmoiscripts/30-setup-mise.sh'* ]]
    server_ignore="$(CHEZMOI_ROLE=server chezmoi --source "$REPO_ROOT" execute-template < "$REPO_ROOT/.chezmoiignore")"
    if [[ "$server_ignore" != *'.chezmoiscripts/30-setup-mise.sh'* ]]; then
        printf 'server role must skip mise setup\n' >&2
        exit 1
    fi
    [[ "$server_ignore" == *'.config/mise'* ]]
fi

printf 'mise migration helper and role checks passed\n'
