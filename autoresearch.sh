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

if rg -q '"skipDangerousModePermissionPrompt"[[:space:]]*:[[:space:]]*true' private_dot_claude/settings.json; then
  add_finding security 'managed Claude settings bypass dangerous-mode permission prompts by default'
fi

if ! rg -qi 'dangerous[- ]mode|permission prompt|approval gate|machine-local|local-only' CLAUDE.md; then
  add_finding guidance 'CLAUDE.md lacks explicit guidance that client safety bypasses should remain opt-in and machine-local'
fi

if ! rg -qi 'permission prompt|dangerous[- ]mode|approval gate|machine-local|local-only' private_dot_agents/private_skills/chezmoi-repo-maintainer/SKILL.md; then
  add_finding guidance 'chezmoi-repo-maintainer skill lacks guardrails for committed client-config safety bypasses'
fi

if ! rg -q '^## First Pass$' CLAUDE.md || ! rg -q 'jj status' CLAUDE.md || ! rg -qi 'load the relevant skill|invoke these skills|skill before' CLAUDE.md; then
  add_finding guidance 'CLAUDE.md lacks a concise first-pass workflow for status checks and skill loading'
fi

if ! rg -qi 'plan|plans/README.md' private_dot_agents/private_skills/chezmoi-repo-maintainer/agents/openai.yaml || ! rg -qi 'chezmoi diff|chezmoi apply|chezmoi status|validate' private_dot_agents/private_skills/chezmoi-repo-maintainer/agents/openai.yaml; then
  add_finding guidance 'repo-maintainer Codex metadata prompt lacks planning/validation reminders'
fi

if ! rg -q 'skipDangerousModePermissionPrompt' dot_local/bin/executable_chezmoi-health-check; then
  add_finding security 'chezmoi-health-check does not sanity-check the Claude dangerous-mode prompt setting'
fi

if ! rg -q '\.agents/skills' dot_local/bin/executable_chezmoi-health-check || ! rg -q '\.codex/skills' dot_local/bin/executable_chezmoi-health-check || ! rg -q '\.claude/skills' dot_local/bin/executable_chezmoi-health-check; then
  add_finding guidance 'chezmoi-health-check does not verify shared agent-skill routing for Codex and Claude'
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
