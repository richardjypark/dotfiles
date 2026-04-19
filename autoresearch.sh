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

if rg -q '~/.codex/config.toml' private_dot_codex/private_config.toml.tmpl \
  || ! rg -q 'codex -c' private_dot_codex/private_config.toml.tmpl; then
  add_finding security 'Codex trust override guidance points to a managed config file instead of a concrete client-supported override mechanism'
fi

if rg -q 'local untracked override' CLAUDE.md \
  && ! rg -q -- '--settings|--setting-sources' CLAUDE.md; then
  add_finding guidance "CLAUDE.md mentions local overrides without naming Claude's actual settings override mechanisms"
fi

if rg -q 'local untracked overrides' docs/tooling-and-skills.md \
  && { ! rg -q 'codex -c' docs/tooling-and-skills.md \
       || ! rg -q -- '--settings|--setting-sources' docs/tooling-and-skills.md; }; then
  add_finding guidance 'docs/tooling-and-skills uses generic override guidance without concrete Codex/Claude override examples'
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
