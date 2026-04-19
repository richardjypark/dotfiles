#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from pathlib import Path
json.loads(Path('private_dot_claude/settings.json').read_text())
PY

bash -n dot_local/bin/executable_chezmoi-health-check

chezmoi apply --dry-run \
  "$HOME/.claude/settings.json" \
  "$HOME/.agents/skills/chezmoi-repo-maintainer/SKILL.md" \
  "$HOME/.agents/skills/chezmoi-repo-maintainer/agents/openai.yaml" \
  "$HOME/.local/bin/chezmoi-health-check" \
  >/dev/null
