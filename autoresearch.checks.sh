#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import tomllib
from pathlib import Path
json.loads(Path('.claude/settings.local.json').read_text())
json.loads(Path('private_dot_claude/settings.json').read_text())
json.loads(Path('dot_pi/agent/settings.json').read_text())
json.loads(Path('dot_pi/agent/keybindings.json').read_text())
tomllib.loads(Path('.chezmoidata.toml').read_text())
tomllib.loads(Path('.chezmoiversion.toml').read_text())
PY

chezmoi execute-template < .chezmoiexternal.toml.tmpl \
  | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
chezmoi execute-template < private_dot_codex/private_config.toml.tmpl \
  | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
chezmoi cat "$HOME/.codex/config.toml" \
  | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
chezmoi cat "$HOME/.codex/AGENTS.md" >/dev/null
chezmoi cat "$HOME/.claude/settings.json" \
  | python3 -c 'import sys, json; json.loads(sys.stdin.read())'
chezmoi cat "$HOME/.pi/agent/settings.json" \
  | python3 -c 'import sys, json; json.loads(sys.stdin.read())'
chezmoi cat "$HOME/.pi/agent/keybindings.json" \
  | python3 -c 'import sys, json; json.loads(sys.stdin.read())'
chezmoi cat "$HOME/.zshrc" | zsh -n
chezmoi cat "$HOME/.agents/skills/chezmoi-repo-maintainer/agents/openai.yaml" \
  | ruby -e 'require "yaml"; YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true)' >/dev/null
chezmoi cat "$HOME/.agents/skills/chezmoi-script-maintainer/agents/openai.yaml" \
  | ruby -e 'require "yaml"; YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true)' >/dev/null
chezmoi cat "$HOME/.agents/skills/chezmoi-bootstrap-operator/agents/openai.yaml" \
  | ruby -e 'require "yaml"; YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true)' >/dev/null
chezmoi cat "$HOME/.agents/skills/dotfiles-version-refresh/agents/openai.yaml" \
  | ruby -e 'require "yaml"; YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true)' >/dev/null
chezmoi cat "$HOME/.agents/skills/jj/agents/openai.yaml" \
  | ruby -e 'require "yaml"; YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true)' >/dev/null

bash -n dot_local/bin/executable_chezmoi-health-check
chezmoi cat "$HOME/.local/bin/chezmoi-health-check" | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_before_00-prerequisites.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_20-setup-fzf.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_24-setup-neovim.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_30-setup-node.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_35-setup-claude-code.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_35-setup-pi-cli.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_36-setup-codex.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl | bash -n
bash -n .chezmoiscripts/run_after_99-performance-summary.sh

check_tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$check_tmpdir"
}
trap cleanup EXIT

tmux_check_file="$check_tmpdir/tmux.conf"
tmux_check_socket="autoresearch-check-$$"
chezmoi cat "$HOME/.tmux.conf" > "$tmux_check_file"
tmux -L "$tmux_check_socket" -f /dev/null start-server \; source-file "$tmux_check_file" \; kill-server >/dev/null 2>&1

check_home="$check_tmpdir/home"
check_state_dir="$check_tmpdir/state"
mkdir -p "$check_home/.local/lib" "$check_home/.cache/chezmoi-state" "$check_state_dir"
cp dot_local/private_lib/chezmoi-helpers.sh "$check_home/.local/lib/chezmoi-helpers.sh"
chezmoi execute-template < .chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl > "$check_tmpdir/run_after_38.sh"
chmod +x "$check_tmpdir/run_after_38.sh"
HOME="$check_home" VERBOSE=false "$check_tmpdir/run_after_38.sh" >/dev/null
: > "$check_state_dir/example.done"
HOME="$check_home" STATE_DIR="$check_state_dir" VERBOSE=false bash .chezmoiscripts/run_after_99-performance-summary.sh >/dev/null

