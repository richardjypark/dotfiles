#!/usr/bin/env bash
# Compatibility entry point for apply and bootstrap scripts.
if [ -n "${CHEZMOI_HELPERS_LOADED:-}" ]; then return 0 2>/dev/null || true; fi
CHEZMOI_HELPERS_DIR="${BASH_SOURCE[0]%/*}"
if [ "$CHEZMOI_HELPERS_DIR" = "${BASH_SOURCE[0]}" ]; then CHEZMOI_HELPERS_DIR=.; fi
. "$CHEZMOI_HELPERS_DIR/chezmoi/core.sh" || return 1
. "$CHEZMOI_HELPERS_DIR/chezmoi/artifacts.sh" || return 1
. "$CHEZMOI_HELPERS_DIR/chezmoi/npm.sh" || return 1
CHEZMOI_HELPERS_LOADED=1
