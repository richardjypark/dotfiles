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

if rg -q 'trust_level = "trusted"' private_dot_codex/private_config.toml.tmpl \
  && { ! rg -qi 'repo-local|repo local|AGENTS|skills' private_dot_codex/private_config.toml.tmpl \
       || ! rg -qi 'local untracked override|local override|machine-local|local-only|untracked' private_dot_codex/private_config.toml.tmpl; }; then
  add_finding security 'tracked Codex trusted-workspace config lacks explicit rationale and local-override guidance'
fi

if ! rg -q '\.codex/AGENTS\.md' dot_local/bin/executable_chezmoi-health-check \
  || ! rg -q '\.codex/config\.toml' dot_local/bin/executable_chezmoi-health-check; then
  add_finding guidance 'chezmoi-health-check does not verify Codex AGENTS/config presence'
fi

if ! rg -q '~/.codex/AGENTS.md' docs/tooling-and-skills.md; then
  add_finding guidance 'docs/tooling-and-skills does not document the routed ~/.codex/AGENTS.md entry point'
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
