---
name: chezmoi-bootstrap-operator
description: "Maintain bootstrap workflows for this dotfiles repo across Omarchy and Debian/Ubuntu VPS paths. Trigger when work touches bootstrap command selection, bootstrap scripts, or server lockdown behavior."
---

# Chezmoi Bootstrap Operator

## When to use this skill

Use this skill when:

- choosing the correct bootstrap command or flags for a machine role/profile
- editing `scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, or `scripts/server-lockdown-tailscale.sh`
- changing bootstrap sequencing, trust gates, or server lockdown behavior

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `references/bootstrap-matrix.md`

## Workflow

1. Determine the target path:
   - Omarchy machine: `scripts/bootstrap-omarchy.sh`
   - Debian/Ubuntu VPS: `bootstrap-vps.sh`
   - post-bootstrap hardening: `scripts/server-lockdown-tailscale.sh`
2. Load command and flag details from `references/bootstrap-matrix.md`.
3. Apply the smallest safe change:
   - keep default-safe behavior (no implicit trust of remote installers)
   - keep role behavior consistent (`workstation` vs `server`)
   - preserve the private-env pattern (`~/.config/dotfiles/bootstrap-private.env`)
4. Update docs when user-visible behavior changes:
   - `~/.local/share/chezmoi/README.md` sections for setup, flags, and role/profile behavior

## References

- `references/bootstrap-matrix.md` for the supported bootstrap paths, trust-gate defaults, and private-input handling

## Stop and ask

- the change would weaken security defaults
- private bootstrap values would move into tracked files
- a lockdown change could cut off SSH or Tailscale access or make recovery unclear

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
