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

audit_prompt() {
  local skill="$1"
  local prompt="$2"
  local reference="$3"

  if ! rg -q 'ARCHITECTURE' "$prompt"; then
    add_finding guidance "$skill Codex metadata prompt lacks the skill's ARCHITECTURE read-first reminder"
  fi

  if ! rg -q "$reference" "$prompt"; then
    add_finding guidance "$skill Codex metadata prompt lacks the skill-specific read-first reference ($reference)"
  fi
}

audit_prompt chezmoi-script-maintainer \
  private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml \
  'script-patterns.md'
audit_prompt chezmoi-bootstrap-operator \
  private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml \
  'bootstrap-matrix.md'
audit_prompt dotfiles-version-refresh \
  private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml \
  'version-map.md'

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
