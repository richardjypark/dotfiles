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

if ! rg -q '\.claude/settings\.local\.json' docs/tooling-and-skills.md; then
  add_finding guidance 'docs/tooling-and-skills does not mention the tracked repo-local .claude/settings.local.json policy file'
fi

if ! rg -q '\.claude/' AGENTS.md; then
  add_finding guidance 'AGENTS.md does not surface .claude/ as an agent-operating surface'
fi

if ! rg -q '\.claude/' ARCHITECTURE.md; then
  add_finding guidance 'ARCHITECTURE.md does not route .claude/ as an agent-config surface'
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
