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

state_line="$(rg -n '^\- \*\*State files:\*\*' CLAUDE.md || true)"
if [[ "$state_line" != *"chezmoi-rerun-script"* ]]; then
  add_finding guidance 'CLAUDE.md state-file guidance does not mention chezmoi-rerun-script for targeted reruns'
fi

if [[ "$state_line" != *"full rerun"* && "$state_line" != *"full re-run"* ]]; then
  add_finding guidance 'CLAUDE.md state-file guidance does not reserve clearing ~/.cache/chezmoi-state for full reruns'
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
