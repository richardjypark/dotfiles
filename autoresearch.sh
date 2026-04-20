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

for command_entrypoint in \
  'bash -n dot_local/bin/executable_czu' \
  'bash -n dot_local/bin/executable_czuf' \
  'bash -n dot_local/bin/executable_czl' \
  'bash -n dot_local/bin/executable_czm' \
  'bash -n dot_local/bin/executable_czb' \
  'bash -n dot_local/bin/executable_czvc' \
  'bash -n dot_local/bin/executable_chezmoi-rerun-script'; do
  if ! rg -qF "$command_entrypoint" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not validate ${command_entrypoint#bash -n }"
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
