# Script Patterns

Use these patterns for `.chezmoiscripts/*`.

## Canonical Header Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if state_exists "<task>"; then
  vecho "<task> already completed (state tracked)"
  exit 0
fi
```

## Trust Gate for Remote Installers

```bash
if [ "${TRUST_ON_FIRST_USE_INSTALLERS:-0}" != "1" ]; then
  eecho "Refusing remote installer without explicit trust."
  eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1."
  exit 1
fi
```

## Role Gate Pattern

```bash
if [ "${CHEZMOI_ROLE:-}" = "server" ]; then
  vecho "Skipping <tool> setup on server role"
  exit 0
fi
```

## Existing Files to Reuse

- Shared helper library: `dot_local/private_lib/chezmoi-helpers.sh`
- Prereq package installs: `.chezmoiscripts/run_before_00-prerequisites.sh`
- Role-gated tool setup: `.chezmoiscripts/run_after_36-setup-codex.sh`
- Installer trust gate examples:
  - `.chezmoiscripts/run_after_35-setup-claude-code.sh`
  - `.chezmoiscripts/run_after_37-setup-tailscale.sh`
- Templated script examples:
  - `.chezmoiscripts/run_after_25-setup-uv.sh.tmpl`
  - `.chezmoiscripts/run_after_30-setup-node.sh.tmpl`

## Order and Naming

- `run_before_XX-*` for prerequisites.
- `run_after_XX-*` for post-apply tasks.
- Reserve lower numbers for foundational dependencies.
- Keep one responsibility per script.
