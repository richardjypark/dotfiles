---
name: jj
description: "Use Jujutsu (jj) for Git-backed version control workflows: inspect status/history, create and reshape changes, recover from bad rewrites, manage bookmarks, and use repo helpers to publish or inspect changes safely. Trigger this skill when the user asks for commit, history, rebase, recovery, bookmark, push, or other jj operations in a jj-backed repo."
---

# Jujutsu Workflow

## When to use this skill

Use this skill when the task is primarily about repository history or publishing state, not about editing the repo's runtime files.

- To reset local jj to a remote source-of-truth branch, repair a divergent or conflicted graph, or fix per-repo `trunk()` behavior, also load `jj-remote-truth-reset`.
- To inspect or edit this skill, the jj Pi agent, the JJFast command, or their wrapper scripts, work locally. Do not route back through the `jj` subagent or `jj-fast-agent`.

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md` when the VCS task is coupled to a larger repo change

## Choose the path

1. **Local fast path (default):** status/log inspection, committing the current change, moving a named bookmark, and publishing an explicit bookmark.
2. **Delegate** only complex history shaping, recovery, or ambiguous sync where a specialist loop is worth the extra turns. Use the `jj` subagent when the client has one; otherwise run `jj-fast-agent` from bash (heredoc for long task text, `--model default` when Spark is unavailable). Model and environment overrides are in `docs/tooling-and-skills.md`. If you delegate a routine task anyway, say: "fast path only; do not read docs/help unless a command fails; empty `@` after `jj commit` is normal; use `<bookmark>@<remote>` verification; report every mutating or failed command."
3. Load `references/jj-reference.md` for history shaping, conflicts, recovery, revsets, and the interactive `jji` / `jjbi` / `jjfi` helpers.

## Local workflow

1. Start with `jj status`. For history or publishing tasks, also run `jj log -r '::@' --limit 12` and `jj diff --summary`. Run full `jj diff` only when you need content details.
2. Commit with a conventional message. The committed change is then `@-`, and jj creates a new empty `@`. Do not run `jj abandon`, `jj edit`, or `jj squash` only to remove that empty `@`.
3. Move a bookmark with `jj bookmark move --to @- <bookmark>`. Confirm the bookmark and remote with `jj bookmark list --all` first.
4. Publish:
   - **This dotfiles repo:** run `dotfiles-push --bookmark <bookmark> --remote <remote>`. It checks private paths, outgoing commit emails, and secrets before it pushes. The `jj push` alias runs the same command only when the clone has the repo-local alias (`jj config list --repo`); otherwise it is raw `jj git push`. Raw `jj git push` skips these checks because jj does not run Git hooks.
   - **This dotfiles repo, `master`:** GitHub refuses direct pushes to `master`. Create a branch with `jj bookmark create <name> -r @-`, publish it with `dotfiles-push`, then run `gh pr create --base master --head <name> --fill` and `gh pr merge <name> --auto --merge --delete-branch`. GitHub merges it after the required checks pass. After the merge, run `jj git fetch` and `jj rebase -r @ -d master`. Never bypass the `master` rulesets.
   - **Other repos:** run `jj git push --remote <remote> -b <bookmark>`.
5. Verify with `jj log -r '<bookmark>@<remote>' --no-graph` and `jj status`. Remote bookmark syntax is `master@origin`, not `origin/master` or `@origin`.
6. After every history-changing command, check `jj log` and `jj status` again. If a rewrite goes wrong, run `jj undo` at once. If you already moved on, use the recovery section in `references/jj-reference.md` before you try another rewrite.
7. Do not issue parallel tool calls when a command mutates repository state or depends on an earlier result. Put dependent commands in one ordered shell command.
8. `jj fetch` is a quiet alias; run raw `jj git fetch` when you need diagnostics.

## Stop and ask

- the intended bookmark, remote, or push target is ambiguous
- the operation would rewrite, abandon, or publish someone else's work
- the operation would restore someone else's work
- the request requires `jj restore --to` / `jj restore --from` or reverting files you did not author without explicit written instruction
- it is unclear whether the user wants inspection only or a history-changing action
