---
name: chezmoi-repo-maintainer
description: "Maintain this chezmoi dotfiles repo when work spans docs, templates, shell/tmux behavior, agent instructions, or multiple subsystems. Use when no narrower skill cleanly covers the task."
---

# Chezmoi Repo Maintainer

## When to use this skill

Use this skill when:

- the task is cross-cutting and does not fit bootstrap, script-maintainer, version-refresh, or jj alone
- editing `~/.local/share/chezmoi/AGENTS.md`, `~/.local/share/chezmoi/CLAUDE.md`, repo docs, Codex/Claude skills, or other agent-operating files
- changing shell/tmux behavior or templates in a way that spans multiple subsystems

## Read first

- `~/.local/share/chezmoi/README.md`
- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `~/.local/share/chezmoi/plans/README.md` for the local scratch-plan convention on multi-step or high-impact work

## Workflow

1. Map the request to the affected subsystem(s) using `~/.local/share/chezmoi/ARCHITECTURE.md`.
2. Prefer the smallest source-of-truth change; do not edit rendered files in `~/`.
3. For high-impact or multi-step work, create local-only `plans/YYYY-MM-DD-<slug>-research.md` and `plans/YYYY-MM-DD-<slug>-plan.md` artifacts before mutating the repo, and do not commit them.
4. Treat the plan as the implementation contract: revise it from inline notes until it is decision-complete, then wait for explicit user approval before implementing.
5. Pull in narrower skills once the work enters a specialized area:
   - bootstrap
   - `.chezmoiscripts/*`
   - version pins / externals
   - jj history operations
6. Keep shared Codex/Claude safety and validation rules aligned unless a tool-specific difference is intentional, but treat the Codex planning workflow as canonical when shared docs need a single source of truth.

## References

- `~/.local/share/chezmoi/README.md` for bootstrap and user-facing workflow context
- `~/.local/share/chezmoi/ARCHITECTURE.md` for subsystem boundaries and validation routing
- `~/.local/share/chezmoi/plans/README.md` for the local research/plan workflow

## Stop and ask

- the change would weaken security defaults or alter secret handling
- a tracked `private_dot_codex/*` or `private_dot_claude/*` change would lower permission prompts, approval gates, or other safety confirmations by default
- it is unclear whether behavior belongs in root docs, a skill, or a tool-specific config file
- deleting a file seems like the easiest way to resolve drift or validation issues

## Validation

```bash
chezmoi diff
chezmoi apply
chezmoi status
```

Then run the subsystem-specific checks called out by `~/.local/share/chezmoi/ARCHITECTURE.md` for any shell, tmux, script, or bootstrap paths you touched.
