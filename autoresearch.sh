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

if ! rg -q 'jj status' private_dot_agents/private_skills/jj/agents/openai.yaml \
  || ! rg -q 'jj log' private_dot_agents/private_skills/jj/agents/openai.yaml \
  || ! rg -q 'jj diff' private_dot_agents/private_skills/jj/agents/openai.yaml; then
  add_finding guidance "jj Codex metadata prompt lacks the skill's preferred jj status/log/diff first-pass reminders"
fi

if ! rg -qi 're-check|after rewrites|jj undo|bookmark' private_dot_agents/private_skills/jj/agents/openai.yaml; then
  add_finding guidance 'jj Codex metadata prompt lacks rewrite recovery or post-change recheck reminders'
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
