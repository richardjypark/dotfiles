---
name: chezmoi-script-maintainer
description: "Maintain `.chezmoiscripts/*` setup scripts in this repo. Trigger when work touches run_before/run_after scripts, helper-driven installer logic, or role/profile-gated tool setup behavior."
---

# Chezmoi Script Maintainer

## When to use this skill

Use this skill when:

- editing `.chezmoiscripts/run_before_*` or `.chezmoiscripts/run_after_*`
- changing helper-driven install/setup behavior
- adding or adjusting trust gates, role/profile guards, or state tracking for setup tasks

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `references/script-patterns.md`

## Workflow

1. Inspect adjacent scripts to match naming and ordering:
   - `run_before_*.sh` for prerequisites
   - `run_after_*.sh` for post-apply setup
2. Reuse existing helpers and guard patterns:
   - installer trust gate (`TRUST_ON_FIRST_USE_INSTALLERS`)
   - role gate (`CHEZMOI_ROLE=server`)
   - optional interactive sudo gate (`CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO`)
3. Keep changes idempotent:
   - repeated `chezmoi apply` should avoid re-running expensive work
4. Update docs when user-visible behavior changes:
   - `~/.local/share/chezmoi/README.md` for setup, role, or command changes

## References

- `references/script-patterns.md` for reusable script headers, trust gates, role gates, and file-order conventions

## Stop and ask

- the change needs new secret input or touches private env handling
- an installer would become implicitly trusted or interactive by default
- it is unclear whether the logic belongs in `.chezmoiscripts/*`, bootstrap, or version-pin data

## Required Script Contract

Follow `references/script-patterns.md`. For new scripts:

- Use `#!/usr/bin/env bash` and `set -euo pipefail` unless `sh` compatibility is required.
- Define `VERBOSE`, `vecho`, and `eecho` with quiet-by-default output.
- Use `STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"`.
- Add an early state-file exit when the task is one-time setup.
- Prefer fast checks before installers (for example, command existence + version check).
- Keep non-interactive defaults; only use interactive sudo when explicitly gated.

## Validation

```bash
bash -n .chezmoiscripts/*.sh
chezmoi apply --dry-run
```

When editing `.tmpl` scripts, validate rendered output:

```bash
chezmoi execute-template < .chezmoiscripts/run_after_25-setup-uv.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_after_30-setup-node.sh.tmpl | bash -n
```
