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

for non_template in \
  'bash -n .chezmoiscripts/run_onchange_after_10-setup-homebrew.sh' \
  'bash -n .chezmoiscripts/run_onchange_after_28-setup-ansible.sh' \
  'bash -n .chezmoiscripts/run_onchange_after_31-change-shell.sh' \
  'bash -n .chezmoiscripts/run_onchange_before_01-setup-omz.sh'; do
  if ! rg -qF "$non_template" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not validate ${non_template#bash -n }"
  fi
done

for template in \
  '.chezmoiscripts/run_onchange_after_12-setup-starship.sh.tmpl' \
  '.chezmoiscripts/run_onchange_after_26-setup-jj.sh.tmpl' \
  '.chezmoiscripts/run_onchange_after_27-setup-bun.sh.tmpl' \
  '.chezmoiscripts/run_onchange_after_40-setup-tmux.sh.tmpl'; do
  if ! rg -qF "chezmoi execute-template < ${template} | bash -n" autoresearch.checks.sh; then
    add_finding guidance "autoresearch.checks.sh does not validate ${template}"
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
