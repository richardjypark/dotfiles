#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from pathlib import Path
json.loads(Path('.claude/settings.local.json').read_text())
PY

chezmoi execute-template < private_dot_codex/private_config.toml.tmpl \
  | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'

bash -n dot_local/bin/executable_chezmoi-health-check
chezmoi execute-template < .chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl | bash -n

check_tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$check_tmpdir"
}
trap cleanup EXIT

check_home="$check_tmpdir/home"
mkdir -p "$check_home/.local/lib" "$check_home/.cache/chezmoi-state"
cp dot_local/private_lib/chezmoi-helpers.sh "$check_home/.local/lib/chezmoi-helpers.sh"
chezmoi execute-template < .chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl > "$check_tmpdir/run_after_38.sh"
chmod +x "$check_tmpdir/run_after_38.sh"
HOME="$check_home" VERBOSE=false "$check_tmpdir/run_after_38.sh" >/dev/null

chezmoi apply --dry-run \
  "$HOME/.codex/config.toml" \
  "$HOME/.codex/AGENTS.md" \
  "$HOME/.agents/skills/chezmoi-repo-maintainer/agents/openai.yaml" \
  "$HOME/.agents/skills/chezmoi-script-maintainer/agents/openai.yaml" \
  "$HOME/.agents/skills/chezmoi-bootstrap-operator/agents/openai.yaml" \
  "$HOME/.agents/skills/dotfiles-version-refresh/agents/openai.yaml" \
  "$HOME/.agents/skills/jj/agents/openai.yaml" \
  "$HOME/.local/bin/chezmoi-health-check" \
  >/dev/null
