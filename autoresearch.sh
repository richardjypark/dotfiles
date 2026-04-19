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

if ! rg -qi 'core workflow primitives|routine workflow primitives' CLAUDE.md; then
  add_finding guidance 'CLAUDE.md does not state that tracked repo-local Claude permissions are reserved for core workflow primitives'
fi

if ! rg -qi 'explicit approval|prompt.*one-off|one-off.*prompt' CLAUDE.md; then
  add_finding guidance 'CLAUDE.md does not state that one-off convenience commands should rely on explicit approval'
fi

if ! rg -qi 'core workflow primitives|routine workflow primitives' docs/tooling-and-skills.md; then
  add_finding guidance 'docs/tooling-and-skills.md does not state that tracked repo-local Claude permissions are reserved for core workflow primitives'
fi

if ! rg -qi 'explicit approval|prompt.*one-off|one-off.*prompt' docs/tooling-and-skills.md; then
  add_finding guidance 'docs/tooling-and-skills.md does not state that one-off convenience commands should rely on explicit approval'
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
