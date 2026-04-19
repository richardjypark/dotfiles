#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from pathlib import Path
json.loads(Path('private_dot_claude/settings.json').read_text())
PY

chezmoi apply --dry-run \
  "$HOME/.claude/settings.json" \
  "$HOME/.agents/skills/chezmoi-repo-maintainer/SKILL.md" \
  >/dev/null
