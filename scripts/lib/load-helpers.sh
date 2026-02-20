#!/usr/bin/env bash
set -euo pipefail

if [ -n "${CHEZMOI_HELPERS_LOADED:-}" ]; then
    return 0
fi

HELPER_PATH="$HOME/.local/lib/chezmoi-helpers.sh"
if [ -f "$HELPER_PATH" ]; then
    # shellcheck disable=SC1090
    . "$HELPER_PATH"
else
    CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
    if [ -n "$CHEZMOI_SOURCE_DIR" ] && [ -f "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" ]; then
        # shellcheck disable=SC1090
        . "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh"
    else
        echo "Error: could not locate chezmoi helper library." >&2
        echo "Expected either $HELPER_PATH or $CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" >&2
        exit 1
    fi
fi

CHEZMOI_HELPERS_LOADED=1
