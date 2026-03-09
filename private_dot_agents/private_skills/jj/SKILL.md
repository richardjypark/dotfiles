---
name: jj
description: "Use Jujutsu (jj) for Git-backed version control workflows: inspect status/history, create and reshape changes, manage bookmarks, and sync with remotes. Trigger this skill when the user asks for commit, history, rebase, bookmark, or push operations in a jj-backed repo."
---

# Jujutsu Workflow

## When to use this skill

Use this skill when the task is primarily about repository history or publishing state, not about editing the repo's runtime files.

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md` when the VCS task is coupled to a larger repo change

## Workflow

1. Confirm the repository state with `jj status`, `jj log -r '::@' --limit 12`, and `jj diff`.
2. Decide which path applies:
   - inspection only: stay with read-only `jj` commands
   - local history shaping: load `references/jj-reference.md` and follow the daily-flow, advanced-workflow, and revset sections
   - publishing: confirm the bookmark target first, then use the bookmark and push guidance in `references/jj-reference.md`
3. After every history-changing command, re-check `jj log` and `jj status`.
4. If a reshape goes wrong, use the recovery guidance in `references/jj-reference.md` before trying another rewrite.

## References

- `references/jj-reference.md` for commands, workflows, aliases, revsets, safety rules, recovery, and git-to-jj mapping

## Stop and ask

- the intended bookmark, remote, or push target is ambiguous
- the operation would rewrite, abandon, or publish someone else's work
- it is unclear whether the user wants inspection only or a history-changing action
