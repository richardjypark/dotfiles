---
name: chezmoi-script-maintainer
description: "Maintain `.chezmoiscripts/*` setup scripts in this repo. Trigger when work touches run_onchange/run_after scripts, helper-driven installer logic, or role/profile-gated tool setup behavior."
---

# Chezmoi Script Maintainer

## When to use this skill

Use this skill when:

- editing `.chezmoiscripts/run_onchange_*` or `.chezmoiscripts/run_after_*`
- changing helper-driven install/setup behavior in `dot_local/private_lib/`
- adding or adjusting trust gates, role/profile guards, or state tracking for setup tasks

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `references/script-patterns.md`

## Workflow

1. Inspect adjacent scripts to match naming and ordering:
   - `run_onchange_before_*` for prerequisites
   - `run_onchange_after_*` for most post-apply setup
   - `run_after_*` for the small set of intentional always-run follow-ups
2. Reuse the shared helpers instead of inline copies (see Required Script Contract).
3. Keep changes idempotent: repeated `chezmoi apply` should skip expensive work.
4. Update `~/.local/share/chezmoi/README.md` when setup, role, or command behavior changes.

## Required Script Contract

Follow `references/script-patterns.md`:

- Use `#!/usr/bin/env bash` and `set -euo pipefail`, then source `$HOME/.local/lib/chezmoi-helpers.sh`. It loads `chezmoi/core.sh`, `artifacts.sh`, and `npm.sh`, which set `VERBOSE`, `STATE_DIR`, `vecho`, and `eecho`. Do not define them again.
- Track one-time work with `state_exists` / `should_skip_state` and `mark_state`.
- Gate remote installers and downloads with `require_trust_for_remote_installer` or `require_trust_for_remote_download` (`TRUST_ON_FIRST_USE_INSTALLERS=1`).
- Keep non-interactive defaults; use interactive sudo only behind `CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO`.
- Prefer fast checks (command exists, version matches) before installers.
- Put shared logic in `dot_local/private_lib/chezmoi/`; tool-specific modules can use a subdirectory, such as `hermes/`.
- A `run_onchange_*` script that uses the helpers includes `{{ includeTemplate "setup/helper-hashes.tmpl" . }}`, so helper edits re-trigger it. Add each new shared module to `.chezmoitemplates/setup/helper-hashes.tmpl`. `run_after_*` scripts run on every apply and need no hash.
- To rerun one remembered `run_onchange_*` script, use `chezmoi-rerun-script <source-script-path>` instead of clearing the whole state directory.

## Stop and ask

- the change needs new secret input or touches private env handling
- an installer would become implicitly trusted or interactive by default
- it is unclear whether the logic belongs in `.chezmoiscripts/*`, bootstrap, or version-pin data

## Validation

```bash
for f in .chezmoiscripts/*; do
  case "$f" in
    *.tmpl) chezmoi execute-template < "$f" | bash -n ;;
    *) bash -n "$f" ;;
  esac || echo "FAIL $f"
done
bash -n dot_local/private_lib/chezmoi-helpers.sh dot_local/private_lib/chezmoi/*.sh
python3 tests/test_setup_recovery.py     # setup recovery, Hermes patches
python3 tests/test_helper_modules.py     # shared helper modules
python3 tests/test_native_installers.py  # native installer recovery
chezmoi apply --dry-run
```
