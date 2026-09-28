---
name: jj-remote-truth-reset
description: "Reset or repair a bad local Jujutsu repo when a remote default branch is the source of truth. Use for local jj history in a bad state, divergent/conflicted local graphs, wrong trunk() behavior, or requests to make local jj reflect the remote branch without hardcoding main/master/dev globally."
---

# JJ Remote Source-of-Truth Reset

## When to use this skill

Use this skill when the user says a local jj repo should be reset to a remote branch, the remote branch/default branch is the source of truth, local history is divergent/conflicted, or `trunk()` is pointing at the wrong branch.

This skill is branch-agnostic. Do not assume `master`, `main`, or `dev`; detect the repo's remote default branch or require an explicit branch from the user.

## Core rule

Do **not** fix per-repo trunk differences with a global `trunk()` alias in the chezmoi-managed jj config (`private_dot_config/jj/config.toml`). Let jj resolve `trunk()` per repo, and write a repo-local override only when one repo needs it.

## Read first

- `~/.agents/skills/jj/SKILL.md` for the base jj workflow and safety rules.
- `~/.agents/skills/jj/references/jj-reference.md` if you need revset, bookmark, or recovery details.

## Safety checks

1. Start with `jj status`, `jj bookmark list --all`, and a short `jj log` before mutating history.
2. If the user has **not** clearly said the remote branch is the source of truth and local-only work may be discarded, stop and ask before `jj abandon`.
3. If a mutating command makes things worse, immediately run `jj undo`.
4. Never use raw destructive Git reset/checkout/restore commands for this workflow.

## Fix `trunk()` for the current repo

The managed helper detects the selected remote's default branch, fetches that remote, and writes a repo-local `trunk()` override when jj's own resolution is missing or not durable:

```bash
jj-sync-trunk               # or: jj trunk-sync
jj-sync-trunk --check       # report a mismatch without writing repo config
jj-sync-trunk --dry-run     # show the repo-local config write
jj-sync-trunk --branch dev  # explicit override when the remote HEAD is wrong
```

To compare by hand: `jj log -r 'trunk()' --no-graph` and `jj log -r '<branch>@<remote>' --no-graph`. The direct repo-local override is:

```bash
jj config set --repo 'revset-aliases."trunk()"' '"<branch>@<remote>"'
```

This writes jj's repo-local config (see `jj config path --repo`), not the project repository or the shared chezmoi config.

## Reset local jj to the remote source of truth

Use this only after the safety checks. It detects the remote default branch (or uses `JJ_TRUNK_BRANCH`), moves the matching local bookmark to it, creates a clean working-copy child, and abandons the old local stack that is not reachable from the remote.

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

If the detected branch is wrong, stop and ask, or rerun with `JJ_TRUNK_BRANCH=<branch>`. Remote bookmark revsets use jj syntax such as `dev@origin`; Git-style `origin/dev` is not valid in jj revsets.

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

After changing the chezmoi-managed jj config, run `chezmoi diff`, `chezmoi apply`, and `chezmoi status`.
