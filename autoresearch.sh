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

if rg -q '^Aliases: `czu`' CLAUDE.md; then
  add_finding guidance 'CLAUDE.md still describes the managed cz* helpers as aliases'
fi

if rg -q 'alias for chezmoi-check-versions' .chezmoiscripts/run_after_99-performance-summary.sh; then
  add_finding guidance 'run_after_99 still labels czvc as an alias instead of a managed command'
fi

if rg -q 'alias for chezmoi-bump' .chezmoiscripts/run_after_99-performance-summary.sh; then
  add_finding guidance 'run_after_99 still labels czb as an alias instead of a managed command'
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
