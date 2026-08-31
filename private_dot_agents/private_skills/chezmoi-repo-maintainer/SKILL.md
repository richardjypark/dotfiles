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
- `~/.local/share/chezmoi/docs/file-layout.md` when work changes path ownership, rendering, or repository structure
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
7. For Codex model-default changes, check the current official model guidance and inspect `codex debug models` for the exact slug, supported reasoning levels, speed tiers, and catalog context window. Prefer leaving `model_context_window` and `model_auto_compact_token_limit` unset so Codex follows current catalog metadata unless a documented provider mismatch requires an override.
8. Keep generated dependency trees out of both repository history and chezmoi target state. Add managed `node_modules/` paths to `.gitignore` and `.chezmoiignore` before running local installs.
9. On macOS, canonicalize `mktemp -d` fixture paths with `cd "$path" && pwd -P` before exact path comparisons; `/var` can resolve to `/private/var`.
10. For validation or CI work, follow `references/validation-and-ci.md` so local and hosted checks use one contract.

## References

- `~/.local/share/chezmoi/README.md` for bootstrap and user-facing workflow context
- `~/.local/share/chezmoi/ARCHITECTURE.md` for subsystem boundaries and validation routing
- `~/.local/share/chezmoi/docs/file-layout.md` for verified source-to-target ownership and repository-only exclusions
- `~/.local/share/chezmoi/plans/README.md` for the local research/plan workflow
- `references/validation-and-ci.md` for portable fixtures, aggregate test runners, managed dependency checks, and Linux/macOS CI convergence

## Stop and ask

- the change would weaken security defaults or alter secret handling
- a tracked `private_dot_codex/*` or `private_dot_claude/*` change would lower permission prompts, approval gates, or other safety confirmations by default
- it is unclear whether behavior belongs in root docs, a skill, or a tool-specific config file
- deleting a file seems like the easiest way to resolve drift or validation issues

## Validation

Run the focused subsystem test during editing. Before completing a task, run:

```bash
./tests/all
chezmoi diff
```

Report skipped suites; they are not passes. Run `chezmoi apply` only at an approved verification gate, then run `chezmoi status`. Also run the subsystem-specific checks called out by `~/.local/share/chezmoi/ARCHITECTURE.md` for any shell, tmux, script, or bootstrap paths you touched.

For validation and CI changes, follow the full sequence in `references/validation-and-ci.md`. Do not claim that hosted CI passed when only a local equivalent was run.

For Codex model changes, also parse the rendered TOML, run `codex doctor` to confirm the config loads, and use a minimal `codex exec` smoke test when authentication and network access are available. Treat unrelated doctor findings as separate follow-up work rather than broadening the model change.
