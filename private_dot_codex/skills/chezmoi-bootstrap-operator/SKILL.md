---
name: chezmoi-bootstrap-operator
description: "Run and maintain bootstrap workflows for this dotfiles repo across Omarchy (Arch) and Debian/Ubuntu VPS paths. Use for selecting the right bootstrap command, updating bootstrap scripts (`scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, `scripts/server-lockdown-tailscale.sh`), handling private env inputs, and preserving secure defaults."
---

# Chezmoi Bootstrap Operator

Use this skill to execute or modify repo bootstrap flows while keeping role behavior and security defaults intact.

## Workflow

1. Determine target path:
- Omarchy machine: use `scripts/bootstrap-omarchy.sh`.
- Debian/Ubuntu VPS: use `bootstrap-vps.sh`.
- Post-bootstrap server lock-down: use `scripts/server-lockdown-tailscale.sh`.

2. Load command and flag details from `references/bootstrap-matrix.md`.

3. Apply the smallest safe change:
- Keep default-safe behavior (no implicit trust of remote installers).
- Keep role behavior consistent (`workstation` vs `server`).
- Preserve private-env pattern (`~/.config/dotfiles/bootstrap-private.env`).

4. Keep docs aligned when behavior changes:
- `README.md` sections for setup profile matrix, bootstrap flags, and role/profile switches.
- `CLAUDE.md` sections for bootstrap and server behavior.

## Validation

Run these checks after edits:

```bash
bash -n scripts/bootstrap-omarchy.sh
bash -n scripts/server-lockdown-tailscale.sh
bash -n bootstrap-vps.sh
```

For behavior checks, run only the relevant command path from `references/bootstrap-matrix.md`.

## Guardrails

- Keep scripts idempotent and non-interactive by default.
- Gate remote installers behind `TRUST_ON_FIRST_USE_INSTALLERS=1`.
- Avoid committing private bootstrap values; keep them in local env files.
- For server changes, preserve phased hardening: verify access first, then tighten SSH/firewall rules.
