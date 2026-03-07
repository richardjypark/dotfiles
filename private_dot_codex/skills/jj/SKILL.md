---
name: jj
description: "Use Jujutsu (jj) for Git-backed version control workflows: inspect status/history, create and reshape changes, manage bookmarks, and sync with remotes. Trigger this skill when the user asks for commit, history, rebase, bookmark, or push operations in a jj-backed repo."
---

# Jujutsu Workflow

Use this skill when the task is primarily about repository history or publishing state, not about editing the repo's runtime files.

## Read First

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md` when the VCS task is coupled to a larger repo change

## Stop And Ask

- the intended bookmark, remote, or push target is ambiguous
- the operation would rewrite, abandon, or publish someone else's work
- it is unclear whether the user wants inspection only or a history-changing action

## Core Concepts

- **Change ID**: Stable identifier (e.g., `kntqzsqt`) that survives rewrites.
- **Commit ID**: Content hash (e.g., `5d39e19d`) that changes when amended.
- **Working copy (`@`)**: Always a commit, auto-updated by jj — no staging area.
- **`@-`**: Parent of working copy. `@--` = grandparent.
- **Bookmarks**: jj's equivalent of git branches; point at a change ID.

## Quick Start

- Confirm repository state: `jj status` (alias: `jj s`)
- Inspect graph before changes: `jj log -r '::@' --limit 12` (alias: `jj l`)
- Show working-copy diff: `jj diff` (alias: `jj d`)
- Show diff stats: `jj ds`
- Shell shortcut: `j` is aliased to `jj`.

## Daily Flow

1. **Start or continue a change.**
   - New change: `jj new -m "type: summary"` (alias: `jj n`)
   - Continue prior change: `jj edit <change-id>` (alias: `jj e`)

2. **Review and shape changes.**
   - Inspect: `jj diff`
   - Reword description: `jj describe -m "type: summary"` (alias: `jj desc`)
   - Move content to parent (amend): `jj squash` (alias: `jj sq`)
   - Interactive squash (select hunks): `jj squash -i`
   - Split change: `jj split` (alias: `jj sp`)
   - Commit working copy and start new change: `jj commit -m "type: summary"` (alias: `jj c`)

3. **Sync with remote.**
   - Fetch: `jj git fetch` (alias: `jj fetch`)
   - Fetch all remotes: `jj sync`
   - Push current bookmark: `jj git push` (alias: `jj push`)
   - Push specific bookmark: `jj git push -b <bookmark>`

## Advanced Workflows

### Insert a change before the current one

Use when you need a prerequisite refactor before your current change:

```bash
jj new -m "feat: implement X"         # start main change
jj new -B -m "refactor: prep work"    # insert change BEFORE current (-B flag)
# ... do prerequisite work ...
jj next --edit                         # return to original change
```

### Stacked changes

```bash
jj new -m "feat: part 1"
# ... work ...
jj new -m "feat: part 2"              # automatically parents on part 1
# ... work ...
jj log -r 'stacked'                   # see trunk()..@ with custom revset
```

### Navigate the stack

- `jj next --edit` — move to child change and edit it.
- `jj prev --edit` — move to parent change and edit it.

### Squash workflow (use `@` like a staging area)

```bash
jj describe -m "feat: implement X"    # describe the real change
jj new                                 # create scratch change on top
# ... make edits ...
jj squash                              # move changes from @ into @- (parent)
```

## Bookmarks and Remote Tracking

- Create bookmark: `jj bookmark create <name>`
- Move bookmark to current change: `jj bookmark move <name>`
- List bookmarks: `jj bookmark list`
- Delete bookmark: `jj bookmark delete <name>`

Ensure the intended bookmark points at the current change before `jj git push`.

## Revsets

### Standard Revsets

| Revset | Description |
|--------|-------------|
| `@` | Current working copy |
| `@-` | Parent of working copy |
| `@--` | Grandparent |
| `root()` | Root commit |
| `trunk()` | Main branch (main/master) |
| `bookmarks()` | All bookmarks |

### Repo Custom Revset Aliases

Defined in `private_dot_config/jj/config.toml.tmpl`:

| Alias | Definition | Use |
|-------|-----------|-----|
| `trunk()` | `latest(present(main@origin) \| present(master@origin))` | Canonical upstream tip |
| `mine` | `author(exact:'rich')` | All my changes |
| `wip` | `description(glob:'wip*')` | Work-in-progress changes |
| `stacked` | `trunk()..@` | Changes between trunk and working copy |

## Config Aliases

Defined in `private_dot_config/jj/config.toml.tmpl`:

| Alias | Expands to | Purpose |
|-------|-----------|---------|
| `l` | `log -r @::` | Log from working copy up |
| `la` | `log -r all()` | Log everything |
| `ll` | `log --limit 20` | Short log |
| `s` | `status` | Working copy status |
| `d` | `diff` | Working copy diff |
| `ds` | `diff --stat` | Diff stats |
| `c` | `commit` | Commit and start new change |
| `n` | `new` | Create new change |
| `e` | `edit` | Resume editing a change |
| `sq` | `squash` | Squash into parent |
| `a` | `abandon` | Discard current change |
| `rb` | `rebase` | Rebase changes |
| `sp` | `split` | Split change |
| `desc` | `describe` | Reword description |
| `push` | `git push` | Push to remote |
| `fetch` | `git fetch` | Fetch from remote |
| `sync` | `git fetch --all-remotes` | Fetch all remotes |

## Conflict Resolution

When conflicts arise (e.g., after rebase):

1. `jj status` — shows conflicted files.
2. Edit files to resolve conflict markers.
3. Changes are auto-tracked; no explicit `add` needed.
4. `jj status` again to confirm resolution.

If the rebase was wrong: `jj undo` to reverse it immediately.

## Safety Rules

### Safe operations (freely use)

- `jj status`, `jj log`, `jj diff`, `jj show` — read-only inspection.
- `jj new`, `jj edit`, `jj describe` — create or annotate changes.
- `jj git fetch` — read-only remote sync.

### Reshaping operations (check log before and after)

- `jj squash`, `jj split`, `jj rebase` — rewrite history.
- `jj abandon` — discard a change.
- Always inspect `jj log` after these to confirm expected graph state.

### Caution-required operations

- `jj git push` — publishes changes to remote; confirm bookmark target first.
- `jj git push --all` — pushes all bookmarks; avoid unless intentional.
- Prefer `jj` commands over raw `git` rewrite commands.

## Recovery

- **Undo last operation**: `jj undo`
- **Redo**: `jj redo`
- **View operation history**: `jj op log`
- **Restore to a specific operation**: `jj op restore <op-id>`

Every jj operation is recorded; nothing is truly lost until garbage-collected.

## Git-to-jj Mapping

| Git | jj | Notes |
|-----|-----|-------|
| `git status` | `jj status` | |
| `git log --graph` | `jj log` | |
| `git add` | *(automatic)* | No staging area |
| `git commit` | `jj commit` or `jj describe` + `jj new` | |
| `git commit --amend` | `jj squash` | Moves @ into @- |
| `git stash` | `jj new` then `jj edit @-` | Leave changes in a new change |
| `git rebase` | `jj rebase` | |
| `git cherry-pick` | `jj new <change-id>` + `jj squash` | |
| `git branch` | `jj bookmark create` | |
| `git push` | `jj git push` | |
| `git fetch` | `jj git fetch` | |
| `git merge` | `jj new <a> <b>` | Merge commit with multiple parents |

## Commit Message Convention

Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
