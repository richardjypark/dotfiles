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

if ! rg -q 'run_onchange_' ARCHITECTURE.md; then
  add_finding guidance 'ARCHITECTURE.md still describes apply-time scripts without mentioning the run_onchange_* paths now used by most setup scripts'
fi

if rg -q '\.chezmoiscripts/run_before_00-prerequisites\.sh\.tmpl' docs/architecture-and-performance.md; then
  add_finding guidance 'docs/architecture-and-performance.md still validates the old run_before_00-prerequisites path'
fi

if ! rg -q 'run_onchange_' private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md; then
  add_finding guidance 'chezmoi-script-maintainer SKILL.md still describes the script namespace without mentioning run_onchange_* paths'
fi

if rg -q '\.chezmoiscripts/run_after_(25|30)-' private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md; then
  add_finding guidance 'chezmoi-script-maintainer SKILL.md still uses stale run_after_* validation examples'
fi

if rg -q '\.chezmoiscripts/run_(before_00|after_(25|30|35|36|37))-' private_dot_agents/private_skills/chezmoi-script-maintainer/references/script-patterns.md; then
  add_finding guidance 'script-patterns.md still points at stale pre-run_onchange script paths'
fi

if rg -q '\.chezmoiscripts/run_after_(20|25|30)-' private_dot_agents/private_skills/dotfiles-version-refresh/SKILL.md; then
  add_finding guidance 'dotfiles-version-refresh SKILL.md still uses stale run_after_* validation examples'
fi

if rg -q '\.chezmoiscripts/run_after_(20|25|30)-' private_dot_agents/private_skills/dotfiles-version-refresh/references/version-map.md; then
  add_finding guidance 'version-map.md still points at stale run_after_* script touchpoints'
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
