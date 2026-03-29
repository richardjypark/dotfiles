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
   - inspection only: stay with read-only `jj` commands, and load `references/jj-reference.md` only if you need targeted inspection helpers such as `jj show -r <rev>`, repo revsets, or the interactive `jji` / `jjbi` / `jjfi` helpers
   - local history shaping: load `references/jj-reference.md` and follow the daily-flow, advanced-workflow, conflict-resolution, and recovery sections; prefer `jj` rewrite commands over raw `git` history edits
   - publishing or sync: list bookmarks with `jj bookmark list`, confirm the bookmark/remote target first, prefer `jj git push -b <bookmark>` when the destination matters, and remember `jj fetch` is quiet so raw `jj git fetch` is better for diagnostics
3. After every history-changing command, re-check `jj log` and `jj status`.
4. If a reshape or rebase goes wrong, use `jj undo` immediately (`jj undo immediately` is usually the fastest recovery path); if you already moved on, use the recovery guidance in `references/jj-reference.md` before trying another rewrite.

## References

- `references/jj-reference.md` for quick-start inspection, shaping workflows, bookmark/push checklists, aliases, interactive helpers, revsets, safety rules, recovery, and git-to-jj mapping

## Stop and ask

- the intended bookmark, remote, or push target is ambiguous
- the operation would rewrite, abandon, or publish someone else's work
- the operation would restore someone else's work
- the request requires `jj restore --to` / `jj restore --from` or reverting files you did not author without explicit written instruction
- it is unclear whether the user wants inspection only or a history-changing action
