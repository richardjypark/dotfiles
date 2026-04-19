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

if rg -Fq 'Bash(chmod:*)' .claude/settings.local.json; then
  add_finding security 'tracked repo-local Claude settings still allow Bash(chmod:*), even though chmod only appears in bootstrap snippets and implementation details'
fi

if ! rg -Fq 'Bash\(chmod:\*\)' dot_local/bin/executable_chezmoi-health-check; then
  add_finding guidance 'chezmoi-health-check does not warn when repo-local Claude settings allow Bash(chmod:*)'
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
