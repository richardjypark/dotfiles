#!/usr/bin/env bash
set -euo pipefail

if [ -n "${CHEZMOI_HELPERS_LOADED:-}" ]; then
    return 0
fi

CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
SOURCE_HELPER="$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh"
HELPER_PATH="$HOME/.local/lib/chezmoi-helpers.sh"
if [ -n "$CHEZMOI_SOURCE_DIR" ] && [ -f "$SOURCE_HELPER" ]; then
    # Before-scripts need the helper from the selected source before it is applied.
    # shellcheck disable=SC1090
    . "$SOURCE_HELPER"
elif [ -f "$HELPER_PATH" ]; then
    # shellcheck disable=SC1090
    . "$HELPER_PATH"
else
    echo "Error: could not locate chezmoi helper library." >&2
    exit 1
fi

CHEZMOI_HELPERS_LOADED=1
