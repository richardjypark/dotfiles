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

expected='for tool in czu czuf czl czm czb czvc chezmoi-health-check chezmoi-rerun-script chezmoi-bump chezmoi-check-versions; do'
if ! rg -qF "$expected" dot_local/bin/executable_chezmoi-health-check; then
  if ! rg -q 'chezmoi-health-check' dot_local/bin/executable_chezmoi-health-check; then
    add_finding guidance 'chezmoi-health-check does not verify the chezmoi-health-check command itself'
  fi
  if ! rg -q 'chezmoi-rerun-script' dot_local/bin/executable_chezmoi-health-check; then
    add_finding guidance 'chezmoi-health-check does not verify the chezmoi-rerun-script helper command'
  fi
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
