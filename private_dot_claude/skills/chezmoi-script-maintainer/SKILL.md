---
name: chezmoi-script-maintainer
description: "Create and modify `.chezmoiscripts/*` setup scripts in this repo with its idempotent conventions. Use when adding new setup scripts, fixing install logic, or changing tool setup behavior while preserving state tracking (`~/.cache/chezmoi-state`), quiet logging (`vecho`/`eecho`), role/profile guards, and trust gates for remote installers."
---

# Chezmoi Script Maintainer

Use this skill for `.chezmoiscripts/` work so behavior stays fast, quiet, and repeatable.

> See `private_dot_codex/skills/chezmoi-script-maintainer/references/script-patterns.md` for canonical patterns.

## Required Script Contract

For new scripts:
- Use `#!/usr/bin/env bash` and `set -euo pipefail` unless `sh` compatibility is required.
- Source the shared helper library: `. "$HOME/.local/lib/chezmoi-helpers.sh"`
- Use `vecho()` for verbose output, `eecho()` for essential output — quiet by default.
- Add an early state-file exit (`state_exists` / `mark_state`) when the task is one-time setup.
- Prefer fast checks before installers (command existence + version check).
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
