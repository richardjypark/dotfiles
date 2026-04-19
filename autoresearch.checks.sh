#!/usr/bin/env bash
set -euo pipefail

chezmoi execute-template < private_dot_codex/private_config.toml.tmpl \
  | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'

bash -n dot_local/bin/executable_chezmoi-health-check

chezmoi apply --dry-run \
  "$HOME/.codex/config.toml" \
  "$HOME/.codex/AGENTS.md" \
  "$HOME/.local/bin/chezmoi-health-check" \
  >/dev/null
