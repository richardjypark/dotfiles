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

for file in private_dot_claude/settings.json dot_pi/agent/settings.json; do
  if ! rg -qF "Path('${file}').read_text()" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not parse ${file}"
  fi
done

for target in '$HOME/.claude/settings.json' '$HOME/.pi/agent/settings.json'; do
  if ! rg -qF "\"${target}\"" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not dry-run ${target}"
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
