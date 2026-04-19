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

if rg -q 'updates the globally installed Pi Coding Agent via npm when present' docs/bootstrap-and-flags.md; then
  add_finding guidance 'docs/bootstrap-and-flags.md still describes czl as updating the Pi Coding Agent via global npm'
fi

if ! rg -q 'managed pinned install during apply instead of a floating global npm update' docs/bootstrap-and-flags.md; then
  add_finding guidance 'docs/bootstrap-and-flags.md does not reflect the current pinned-install wording for Pi updates'
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
