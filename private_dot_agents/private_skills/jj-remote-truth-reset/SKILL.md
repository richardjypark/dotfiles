---
name: jj-remote-truth-reset
description: "Reset or repair a bad local Jujutsu repo when a remote default branch is the source of truth. Use for local jj history in a bad state, divergent/conflicted local graphs, wrong trunk() behavior, or requests to make local jj reflect the remote branch without hardcoding main/master/dev globally."
---

# JJ Remote Source-of-Truth Reset

## When to use this skill

Use this skill when the user says a local jj repo should be reset to a remote branch, the remote branch/default branch is the source of truth, local history is divergent/conflicted, or `trunk()` is pointing at the wrong branch.

This skill is intentionally branch-agnostic. Do not assume `master`, `main`, or `dev`; detect the repo's remote default branch or require an explicit branch from the user.

## Core rule

Do **not** fix per-repo trunk differences by hardcoding a global `trunk()` alias in the chezmoi-managed jj user config.

- Global chezmoi jj config should contain shared aliases/defaults only.
- Let jj resolve built-in `trunk()` per repo when possible.
- If one repo needs a correction, set a repo-local override with `jj config set --repo`.
- Prefer the managed helper `jj-sync-trunk` (or `jj trunk-sync`) so future repos use their detected remote default branch instead of a hardcoded global branch.

## Read first

- `~/.agents/skills/jj/SKILL.md` for the base jj workflow and safety rules.
- `~/.agents/skills/jj/references/jj-reference.md` if you need revset, bookmark, or recovery details.

## Safety checks

1. Start with `jj status`, `jj bookmark list --all`, and a short `jj log` before mutating history.
2. If the user has **not** clearly said the remote branch is the source of truth and local-only work may be discarded, stop and ask before `jj abandon`.
3. If a mutating command makes things worse, immediately run `jj undo`.
4. Never use raw destructive Git reset/checkout/restore commands for this workflow.

## Keep `trunk()` aligned for the current repo

Run the managed helper in any jj repo. It detects the selected remote's HEAD/default branch, fetches that remote, and writes a repo-local `trunk()` override when jj's built-in/common `trunk()` resolution is missing or not durable:

```bash
jj-sync-trunk
# or, through the jj alias:
jj trunk-sync
```

Useful checks:

```bash
jj-sync-trunk --check       # report mismatch without writing repo config
jj-sync-trunk --dry-run     # show the repo-local config write
jj-sync-trunk --branch dev  # explicit one-off override when remote HEAD is wrong
```

## Detect the repo-specific source branch manually

Use the remote default branch instead of hardcoding a branch name. This snippet supports explicit overrides via environment variables and otherwise asks Git for the remote HEAD:

```bash
remote="${JJ_REMOTE:-origin}"
branch="${JJ_TRUNK_BRANCH:-}"

jj git fetch --remote "$remote"

if [ -z "$branch" ]; then
  remote_head_ref=$(git symbolic-ref -q --short "refs/remotes/${remote}/HEAD" || true)
  if [ -n "$remote_head_ref" ]; then
    branch="${remote_head_ref#${remote}/}"
  fi
fi

if [ -z "$branch" ]; then
  branch=$(git remote show -n "$remote" 2>/dev/null | awk -F': ' '/HEAD branch/ && $2 != "(unknown)" && $2 != "(not queried)" {print $2; exit}')
fi

if [ -z "$branch" ]; then
  echo "Could not infer ${remote}'s default branch. Inspect 'git branch -r' and rerun with JJ_TRUNK_BRANCH=<branch>." >&2
  exit 1
fi

source_rev="${branch}@${remote}"
jj --ignore-working-copy log -r "$source_rev" --no-graph
```

If the detected branch is wrong, stop and ask or rerun with an explicit branch, for example:

```bash
JJ_REMOTE=origin JJ_TRUNK_BRANCH=dev <command-or-snippet>
```

## Reset local jj to the remote source of truth

Use this only after the safety checks above. It moves the matching local bookmark to the remote default branch, creates a clean working-copy child from it, and abandons the old local stack that is not reachable from the remote source branch.

```bash
remote="${JJ_REMOTE:-origin}"
branch="${JJ_TRUNK_BRANCH:-}"

jj status
jj bookmark list --all
jj log -r '::@' --limit 12
jj git fetch --remote "$remote"

if [ -z "$branch" ]; then
  remote_head_ref=$(git symbolic-ref -q --short "refs/remotes/${remote}/HEAD" || true)
  if [ -n "$remote_head_ref" ]; then
    branch="${remote_head_ref#${remote}/}"
  fi
fi
if [ -z "$branch" ]; then
  branch=$(git remote show -n "$remote" 2>/dev/null | awk -F': ' '/HEAD branch/ && $2 != "(unknown)" && $2 != "(not queried)" {print $2; exit}')
fi
if [ -z "$branch" ]; then
  echo "Could not infer ${remote}'s default branch. Set JJ_TRUNK_BRANCH=<branch>." >&2
  exit 1
fi

source_rev="${branch}@${remote}"
old_at=$(jj --ignore-working-copy log -r @ --no-graph --template 'commit_id')
cleanup_revset="::${old_at} ~ ::${source_rev} ~ ::remote_bookmarks(remote='${remote}')"

jj --ignore-working-copy log -r "$source_rev" --no-graph
jj-sync-trunk --branch "$branch" --remote "$remote" --no-fetch
jj --ignore-working-copy bookmark set --allow-backwards -r "$source_rev" "$branch"
jj new "$branch"

if jj --ignore-working-copy log -r "$cleanup_revset" --no-graph --template 'commit_id ++ "\n"' | grep -q .; then
  echo "About to abandon these local-only commits because the user confirmed the remote branch is the source of truth:" >&2
  jj --ignore-working-copy log -r "$cleanup_revset" --no-graph
  jj abandon "$cleanup_revset"
fi

jj status
jj bookmark list --all
git status --short
```

Remote bookmark revsets use jj syntax like `dev@origin`, `main@origin`, or `master@origin`; do not use Git-style `origin/dev` in jj revsets.

## Optional full visible-local cleanup

Only use this after inspecting the remaining visible commits that are not reachable from any remote bookmark on the selected remote and not part of the current checkout. This can still include useful local feature work, so require explicit discard confirmation.

```bash
remote="${JJ_REMOTE:-origin}"
local_only_revset="remote_bookmarks(remote='${remote}').. ~ ::@"
jj --ignore-working-copy log -r "heads(${local_only_revset})"
```

If the output is all junk and the user confirmed discard:

```bash
jj abandon "$local_only_revset"
```

Verify:

```bash
jj status
jj bookmark list --all
jj --ignore-working-copy log -r "$local_only_revset" --no-graph --template 'commit_id ++ "\n"' | wc -l
git status --short
```

## Fix wrong `trunk()` behavior per repo

First inspect what `trunk()` resolves to and what the remote default branch resolves to:

```bash
jj log -r 'trunk()' --no-graph
jj log -r "${branch}@${remote}" --no-graph
```

If jj cannot infer the right trunk for that repo, prefer the helper:

```bash
jj-sync-trunk --branch "$branch" --remote "$remote"
```

Or set the repo-local override directly:

```bash
jj config set --repo 'revset-aliases."trunk()"' "\"${branch}@${remote}\""
```

Concrete examples:

```bash
jj config set --repo 'revset-aliases."trunk()"' '"dev@origin"'
jj config set --repo 'revset-aliases."trunk()"' '"main@origin"'
jj config set --repo 'revset-aliases."trunk()"' '"master@origin"'
```

This writes to jj's repo-local config, not to the project repository and not to the shared chezmoi user config. Use `jj config path --repo` if you need to see the exact file.

## Chezmoi shared config rule

In the chezmoi source repo, the managed jj config should **not** define a global `trunk()` alias. The expected shared shape is:

```toml
[revset-aliases]
# Useful revset shortcuts.
# Do not override trunk() globally; jj covers common trunk names, and
# jj-sync-trunk writes repo-local overrides when a repo needs one.
"mine" = "author(exact:'rich')"
"wip" = "description(glob:'wip*')"
"stacked" = "trunk()..@"
```

After changing the chezmoi source, validate and render it:

```bash
chezmoi diff
chezmoi apply
chezmoi status
```
