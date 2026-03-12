# Jujutsu Reference

## Table of Contents

- Core concepts
- Quick start
- Daily flow
- Advanced workflows
- Bookmarks and remote tracking
- Revsets
- Config aliases
- Conflict resolution
- Safety rules
- Recovery
- Git-to-jj mapping
- Commit message convention

## Core Concepts

- **Change ID**: Stable identifier (for example `kntqzsqt`) that survives rewrites.
- **Commit ID**: Content hash (for example `5d39e19d`) that changes when amended.
- **Working copy (`@`)**: Always a commit, auto-updated by jj; there is no staging area.
- **`@-`**: Parent of the working copy. `@--` is the grandparent.
- **Bookmarks**: jj's equivalent of git branches; they point at a change ID.

## Quick Start

- Confirm repository state: `jj status` (alias: `jj s`)
- Inspect graph before changes: `jj log -r '::@' --limit 12` (alias: `jj l`)
- Show working-copy diff: `jj diff` (alias: `jj d`)
- Show diff stats: `jj ds`
- Shell shortcut: `j` is aliased to `jj`

## Daily Flow

1. Start or continue a change.
   - New change: `jj new -m "type: summary"` (alias: `jj n`)
   - Continue prior change: `jj edit <change-id>` (alias: `jj e`)
2. Review and shape changes.
   - Inspect: `jj diff`
   - Reword description: `jj describe -m "type: summary"` (alias: `jj desc`)
   - Move content to parent: `jj squash` (alias: `jj sq`)
   - Interactive squash: `jj squash -i`
   - Split change: `jj split` (alias: `jj sp`)
   - Commit working copy and start new change: `jj commit -m "type: summary"` (alias: `jj c`)
3. Sync with remote.
   - Fetch: `jj fetch` (quiet alias for `jj git fetch`)
   - Fetch all remotes: `jj sync`
   - Push current bookmark: `jj git push` (alias: `jj push`)
   - Push specific bookmark: `jj git push -b <bookmark>`

## Advanced Workflows

### Insert a change before the current one

Use when you need a prerequisite refactor before your current change:

```bash
jj new -m "feat: implement X"
jj new -B -m "refactor: prep work"
# ... do prerequisite work ...
jj next --edit
```

### Stacked changes

```bash
jj new -m "feat: part 1"
# ... work ...
jj new -m "feat: part 2"
# ... work ...
jj log -r 'stacked'
```

### Navigate the stack

- `jj next --edit` moves to a child change and edits it.
- `jj prev --edit` moves to a parent change and edits it.

### Squash workflow

```bash
jj describe -m "feat: implement X"
jj new
# ... make edits ...
jj squash
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
| --- | --- |
| `@` | Current working copy |
| `@-` | Parent of working copy |
| `@--` | Grandparent |
| `root()` | Root commit |
| `trunk()` | Main branch (`main` or `master`) |
| `bookmarks()` | All bookmarks |

### Repo Custom Revset Aliases

Defined in `private_dot_config/jj/config.toml.tmpl`:

| Alias | Definition | Use |
| --- | --- | --- |
| `trunk()` | `latest(present(main@origin) \| present(master@origin))` | Canonical upstream tip |
| `mine` | `author(exact:'rich')` | All my changes |
| `wip` | `description(glob:'wip*')` | Work-in-progress changes |
| `stacked` | `trunk()..@` | Changes between trunk and working copy |

## Config Aliases

Defined in `private_dot_config/jj/config.toml.tmpl`:

| Alias | Expands to | Purpose |
| --- | --- | --- |
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
| `fetch` | `git fetch --quiet` | Fetch from remote without rewrite noise |
| `sync` | `git fetch --all-remotes` | Fetch all remotes |

## Conflict Resolution

When conflicts arise, especially after a rebase:

1. Run `jj status` to identify conflicted files.
2. Edit the files to resolve the conflict markers.
3. Re-run `jj status` to confirm the resolution.

If the rebase itself was wrong, use `jj undo` immediately.

## Safety Rules

### Safe operations

- `jj status`, `jj log`, `jj diff`, `jj show`
- `jj new`, `jj edit`, `jj describe`
- `jj git fetch`

### Reshaping operations

- `jj squash`, `jj split`, `jj rebase`
- `jj abandon`

Inspect `jj log` after these commands to confirm the graph changed the way you intended.

### Caution-required operations

- `jj git push`
- `jj git push --all`

Prefer `jj` rewrite commands over raw `git` history-rewrite commands in this repo.

## Recovery

- Undo last operation: `jj undo`
- Redo: `jj redo`
- View operation history: `jj op log`
- Restore to a specific operation: `jj op restore <op-id>`

Every jj operation is recorded until it is garbage-collected.

## Git-to-jj Mapping

| Git | jj | Notes |
| --- | --- | --- |
| `git status` | `jj status` | |
| `git log --graph` | `jj log` | |
| `git add` | automatic | No staging area |
| `git commit` | `jj commit` or `jj describe` + `jj new` | |
| `git commit --amend` | `jj squash` | Moves `@` into `@-` |
| `git stash` | `jj new` then `jj edit @-` | Leave changes in a new change |
| `git rebase` | `jj rebase` | |
| `git cherry-pick` | `jj new <change-id>` + `jj squash` | |
| `git branch` | `jj bookmark create` | |
| `git push` | `jj git push` | |
| `git fetch` | `jj git fetch` | |
| `git merge` | `jj new <a> <b>` | Merge commit with multiple parents |

## Commit Message Convention

Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
