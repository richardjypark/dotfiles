# Script Patterns

Use these patterns for `.chezmoiscripts/*`.

## Canonical Header Pattern

For a `run_onchange_*` template (`.sh.tmpl`) that uses the helpers:

```bash
#!/usr/bin/env bash
{{ includeTemplate "setup/helper-hashes.tmpl" . }}
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if should_skip_state "<task>"; then
  vecho "<task> already completed (state tracked)"
  exit 0
fi
```

The include line puts the helper hashes into the rendered script, so a helper edit makes chezmoi run the script again. `tests/test_helper_modules.py` fails when a `run_onchange_*` script that sources the helpers leaves it out. `should_skip_state` also honors a forced update (`czuf`); `state_exists` does not.

The helpers provide `VERBOSE`, `STATE_DIR`, `vecho`, `eecho`, `state_exists`, `should_skip_state`, `mark_state`, `add_to_path`, and `run_quiet`.

## Trust Gate for Remote Installers

```bash
if ! require_trust_for_remote_installer "<tool> installer"; then
  exit 1
fi
```

Use `require_trust_for_remote_download "<source>"` for artifact downloads. Both helpers refuse unless `TRUST_ON_FIRST_USE_INSTALLERS=1`.

## Role Gate Pattern

The role comes from `CHEZMOI_ROLE` or the saved chezmoi data, so resolve it at render time:

```bash
if [ "{{ includeTemplate "resolved-role" . }}" = "server" ]; then
  vecho "Skipping <tool> setup on server role"
  exit 0
fi
```

## Existing Files to Reuse

- Shared helper entry point: `dot_local/private_lib/chezmoi-helpers.sh`
- Helper modules: `dot_local/private_lib/chezmoi/` (`core.sh`, `artifacts.sh`, `npm.sh`, `hermes/`)
- Helper hash list: `.chezmoitemplates/setup/helper-hashes.tmpl`
- Prereq package installs: `.chezmoiscripts/run_onchange_before_00-prerequisites.sh.tmpl`
- Role-gated tool setup: `.chezmoiscripts/run_onchange_after_36-setup-codex.sh.tmpl`
- Installer trust gate examples:
  - `.chezmoiscripts/run_onchange_after_35-setup-claude-code.sh.tmpl`
  - `.chezmoiscripts/run_onchange_after_37-setup-tailscale.sh.tmpl`
- Templated script examples:
  - `.chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl`
  - `.chezmoiscripts/run_after_30-setup-mise.sh.tmpl`

## Order and Naming

- `run_onchange_before_XX-*` for prerequisites.
- `run_onchange_after_XX-*` for most post-apply tasks.
- `run_after_XX-*` only for intentional always-run follow-up tasks.
- Reserve lower numbers for foundational dependencies.
- Keep one responsibility per script.
