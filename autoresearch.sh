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

for prompt in \
  private_dot_agents/private_skills/chezmoi-repo-maintainer/agents/openai.yaml \
  private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml \
  private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml \
  private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml
 do
  if ! rg -q 'jj status' "$prompt"; then
    add_finding guidance "$(basename "$(dirname "$(dirname "$prompt")")") Codex metadata prompt lacks the repo's jj status first-pass reminder"
  fi
 done

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
