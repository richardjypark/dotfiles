---
name: chezmoi-script-maintainer
description: "Create and modify `.chezmoiscripts/*` setup scripts in this repo with its idempotent conventions. Use when adding new setup scripts, fixing install logic, or changing tool setup behavior while preserving state tracking (`~/.cache/chezmoi-state`), quiet logging (`vecho`/`eecho`), role/profile guards, and trust gates for remote installers."
---

# Chezmoi Script Maintainer

Use this skill for `.chezmoiscripts/` work so behavior stays fast, quiet, and repeatable.

## Required Script Contract

Follow the patterns in `references/script-patterns.md`.

For new scripts:
- Use `#!/usr/bin/env bash` and `set -euo pipefail` unless `sh` compatibility is required.
- Define `VERBOSE`, `vecho`, and `eecho` with quiet-by-default output.
- Use `STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"`.
- Add an early state-file exit when the task is one-time setup.
- Prefer fast checks before installers (for example, command existence + version check).
- Keep non-interactive defaults; only use interactive sudo when explicitly gated.

## Implementation Workflow

1. Inspect adjacent scripts to match naming and ordering:
- `run_before_*.sh` for prerequisites.
- `run_after_*.sh` for post-apply setup.

2. Reuse existing helpers and guard patterns:
- Installer trust gate (`TRUST_ON_FIRST_USE_INSTALLERS`).
- Role gate (`CHEZMOI_ROLE=server` skip rules where applicable).
- Optional interactive sudo gate (`CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO`).

3. Keep changes idempotent:
- Repeated `chezmoi apply` must not re-run expensive work unnecessarily.

4. Keep docs aligned if behavior changes:
- Update `README.md` and `CLAUDE.md` when setup, role logic, or commands change.

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
