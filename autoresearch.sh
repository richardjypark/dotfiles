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

script='.chezmoiscripts/run_onchange_after_24-setup-neovim.sh.tmpl'

if ! rg -qi 'compatibility floor|steady-state contract|required .*compatib' "$script"; then
  add_finding guidance 'Neovim setup script does not explicitly say REQUIRED_NVIM_VERSION is the compatibility floor / steady-state contract'
fi

if ! rg -qi 'preferred install source|package managers lag|newer versions remain acceptable|pinned .*preferred' "$script"; then
  add_finding guidance 'Neovim setup script does not explicitly say PINNED_NVIM_VERSION is a preferred install source rather than a strict must-match version'
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
