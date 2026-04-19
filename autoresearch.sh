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

if ! rg -qi 'trust gate|TRUST_ON_FIRST_USE_INSTALLERS' private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml \
  || ! rg -qi 'bash -n|chezmoi diff|chezmoi apply|chezmoi status|validate' private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml; then
  add_finding guidance 'script-maintainer Codex metadata prompt lacks trust-gate and validation reminders'
fi

if ! rg -qi 'security defaults|TRUST_ON_FIRST_USE_INSTALLERS|hardening' private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml \
  || ! rg -qi 'bash -n|chezmoi diff|chezmoi apply|chezmoi status|validate' private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml; then
  add_finding guidance 'bootstrap-operator Codex metadata prompt lacks security/validation reminders'
fi

if ! rg -qi 'refresh-externals|externals' private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml \
  || ! rg -qi 'chezmoi apply|chezmoi status|validate' private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml; then
  add_finding guidance 'version-refresh Codex metadata prompt lacks refresh/validation reminders'
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
