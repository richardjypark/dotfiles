---
name: jj
description: "Use Jujutsu (jj) for Git-backed version control workflows: inspect status/history, create and reshape changes, manage bookmarks, and sync with remotes. Trigger this skill when the user asks for commit/history operations and prefers jj over git."
---

# Jujutsu Workflow

## Quick Start

- Confirm repository state: `jj status`
- Inspect graph before changes: `jj log -r '::@' --limit 12`
- Show working-copy diff: `jj diff`

## Daily Flow

1. Start or continue a change.
- New change: `jj new -m "type: summary"`
- Continue prior change: `jj edit <change-id>`

2. Review and shape changes.
- Inspect: `jj diff`
- Split change: `jj split`
- Move content to parent: `jj squash`
- Reword description: `jj describe -m "type: summary"`

3. Sync with remote.
- Fetch: `jj git fetch`
- Push current bookmark or branch: `jj git push`
- Push specific bookmark: `jj git push -b <bookmark>`

## Bookmarks and Remote Tracking

- Create bookmark for current change: `jj bookmark create <name>`
- Move bookmark to current change: `jj bookmark move <name>`
- List bookmarks: `jj bookmark list`

When a remote branch must be updated, ensure the intended bookmark points at the current change before `jj git push`.

## Safety Rules

- Prefer `jj` commands for history edits instead of raw `git` rewrite commands.
- Check `jj log` before and after destructive operations (`squash`, `split`, `rebase`).
- Use `jj undo` immediately if an operation produced an unintended graph state.
- Keep commands non-interactive when possible in automation contexts.

## Git-to-jj Mapping

- `git status` -> `jj status`
- `git log --graph` -> `jj log`
- `git commit --amend` -> `jj squash`
- `git rebase` -> `jj rebase`
- `git push` -> `jj git push`
