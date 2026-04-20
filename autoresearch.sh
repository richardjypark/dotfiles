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

if ! rg -qF 'bash -n dot_local/bin/executable_omarchy-screenshot-active-window-clipboard' .github/workflows/managed-npm-safety.yml; then
  add_finding guidance 'managed-npm-safety workflow does not syntax-check executable_omarchy-screenshot-active-window-clipboard'
fi

if ! rg -qF 'sh -n dot_local/bin/executable_tmux-status-host' .github/workflows/managed-npm-safety.yml; then
  add_finding guidance 'managed-npm-safety workflow does not syntax-check executable_tmux-status-host with sh -n'
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
