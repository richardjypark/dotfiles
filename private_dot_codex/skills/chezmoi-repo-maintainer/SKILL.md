---
name: chezmoi-repo-maintainer
description: "Maintain this chezmoi dotfiles repo when work spans docs, templates, shell/tmux behavior, agent instructions, or multiple subsystems. Use when no narrower skill cleanly covers the task."
---

# Chezmoi Repo Maintainer

Use this skill when:

- the task is cross-cutting and does not fit bootstrap, script-maintainer, version-refresh, or jj alone
- editing `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/CLAUDE.md`, repo docs, Codex/Claude skills, or other agent-operating files
- changing shell/tmux behavior or templates in a way that spans multiple subsystems

## Read First

- `~/.local/share/chezmoi/README.md`
- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `~/.local/share/chezmoi/plans/README.md` for multi-step or high-impact work

## Workflow

1. Map the request to the affected subsystem(s) using `~/.local/share/chezmoi/ARCHITECTURE.md`.
2. Prefer the smallest source-of-truth change; do not edit rendered files in `~/`.
3. Create or update `plans/YYYY-MM-DD-<slug>.md` before mutating the repo when the work is high-impact or multi-step.
4. Pull in narrower skills once the work enters a specialized area:
   - bootstrap
   - `.chezmoiscripts/*`
   - version pins / externals
   - jj history operations
5. Keep shared Codex/Claude safety and validation rules aligned unless a tool-specific difference is intentional.

## Stop And Ask

- the change would weaken security defaults or alter secret handling
- it is unclear whether behavior belongs in root docs, a skill, or a tool-specific config file
- deleting a file seems like the easiest way to resolve drift or validation issues

## Validation

```bash
chezmoi diff
chezmoi apply
chezmoi status
```

Then run the subsystem-specific checks called out by `~/.local/share/chezmoi/ARCHITECTURE.md` for any shell, tmux, script, or bootstrap paths you touched.
