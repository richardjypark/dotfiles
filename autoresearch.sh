#!/usr/bin/env bash
set -euo pipefail

issue_count=0
security_findings=0
guidance_findings=0

findings=()

add_finding() {
  local kind="$1"
  local message="$2"
  findings+=("$kind: $message")
  issue_count=$((issue_count + 1))
  case "$kind" in
    security)
      security_findings=$((security_findings + 1))
      ;;
    guidance)
      guidance_findings=$((guidance_findings + 1))
      ;;
  esac
}

for target in \
  '$HOME/.codex/config.toml' \
  '$HOME/.codex/AGENTS.md' \
  '$HOME/.agents/skills/chezmoi-repo-maintainer/agents/openai.yaml' \
  '$HOME/.agents/skills/chezmoi-script-maintainer/agents/openai.yaml' \
  '$HOME/.agents/skills/chezmoi-bootstrap-operator/agents/openai.yaml' \
  '$HOME/.agents/skills/dotfiles-version-refresh/agents/openai.yaml' \
  '$HOME/.agents/skills/jj/agents/openai.yaml' \
  '$HOME/.local/bin/chezmoi-health-check'; do
  if ! rg -qF "chezmoi cat \"${target}\"" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not non-interactively validate ${target}"
  fi
done

if rg -qF 'chezmoi apply --dry-run' autoresearch.checks.sh; then
  add_finding guidance 'autoresearch.checks.sh still relies on chezmoi apply --dry-run for managed target validation'
fi

printf 'Audit findings (%s):\n' "$issue_count"
if [ "$issue_count" -eq 0 ]; then
  printf '  none\n'
else
  for finding in "${findings[@]}"; do
    printf '  %s\n' "$finding"
  done
fi

printf 'METRIC issue_count=%s\n' "$issue_count"
printf 'METRIC security_findings=%s\n' "$security_findings"
printf 'METRIC guidance_findings=%s\n' "$guidance_findings"
