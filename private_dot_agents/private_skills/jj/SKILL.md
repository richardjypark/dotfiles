---
name: jj
description: "Use Jujutsu (jj) for Git-backed version control workflows: inspect status/history, create and reshape changes, recover from bad rewrites, manage bookmarks, and use repo helpers to publish or inspect changes safely. Trigger this skill when the user asks for commit, history, rebase, recovery, bookmark, push, or other jj operations in a jj-backed repo."
---

# Jujutsu Workflow

## When to use this skill

Use this skill when the task is primarily about repository history or publishing state, not about editing the repo's runtime files.

Do not route back through the jj subagent or `jj-fast-agent` when the task is to inspect or edit the jj skill, the jj Pi agent, the JJFast command, or their wrapper scripts. Treat that as repo-maintenance work and inspect locally.

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md` when the VCS task is coupled to a larger repo change

## Workflow

1. For simple explicit jj tasks, use the local fast path directly instead of delegating. This includes status/log inspection, committing the current working-copy change, moving a named bookmark, and pushing an explicit bookmark/remote such as `master` to `origin`.
2. Delegate to the `jj` subagent only for complex history shaping, recovery, ambiguous publishing/sync, or multi-step inspection where a specialist loop is worth the extra turns. It runs with `openai-codex/gpt-5.3-codex-spark:minimal` and carries the repo's jj workflow. If you must delegate a routine commit/push anyway, explicitly say: "fast path only; do not read docs/help unless a command fails; empty `@` after `jj commit` is normal; use `<bookmark>@<remote>` verification; report every mutating or failed command."
3. If delegation is unavailable or inappropriate but `jj-fast-agent` is available in `PATH`, invoke it via bash for complex jj/git-only work before manual `jj` or `git` commands and use its result as the primary answer. Prefer a stdin-safe form such as `jj-fast-agent <<'EOF' ... EOF` when the task text is long or contains quotes. `jj-fast-agent` is a tool-agnostic wrapper around the same `jj` Pi agent, so this path works from other CLIs such as Codex too.
4. Only if the task is self-maintenance for this skill/JJFast path, also requires broader repo editing, is simple enough for the local fast path, or both delegation paths are unavailable or failed, continue locally with the steps below.
5. Start local inspection with `jj status`. For history-changing or publishing tasks, also inspect `jj log -r '::@' --limit 12`. Use `jj diff --summary` first, and run full `jj diff` only when content details are needed.
6. For routine “commit current changes and push bookmark” requests with an explicit target:
   - inspect once with `jj status`, `jj log -r '::@' --limit 12`, `jj diff --summary`, targeted/full diff only as needed, and `jj bookmark list --all`
   - commit with a conventional message, then remember the committed change is `@-` because jj creates a new empty working-copy commit at `@`
   - move the named bookmark with `jj bookmark move --to @- <bookmark>` and push with `jj git push --remote <remote> -b <bookmark>`
   - verify with `jj log -r '<bookmark>@<remote>' --no-graph` and `jj status`; remote bookmark syntax is `master@origin`, not `origin/master` or `@origin`
   - do not run `jj abandon`, `jj edit`, or `jj squash` merely to remove the normal empty `@` after `jj commit`
7. Decide which path applies:
   - inspection only: stay with read-only `jj` commands, and load `references/jj-reference.md` only if you need targeted inspection helpers such as `jj show -r <rev>`, repo revsets, or the interactive `jji` / `jjbi` / `jjfi` helpers
   - local history shaping: load `references/jj-reference.md` and follow the daily-flow, advanced-workflow, conflict-resolution, and recovery sections; prefer `jj` rewrite commands over raw `git` history edits
   - publishing or sync: list bookmarks with `jj bookmark list`, confirm the bookmark/remote target first, prefer `jj git push -b <bookmark>` when the destination matters, and remember `jj fetch` is quiet so raw `jj git fetch` is better for diagnostics
8. Never issue parallel tool calls when any command mutates repository state or depends on a previous command's result; combine dependent commands into one ordered shell command.
9. After every history-changing command, re-check `jj log` and `jj status`.
10. If a reshape or rebase goes wrong, run `jj undo` immediately (the command is just `jj undo`); if you already moved on, use the recovery guidance in `references/jj-reference.md` before trying another rewrite.

## References

- `references/jj-reference.md` for quick-start inspection, shaping workflows, bookmark/push checklists, aliases, interactive helpers, revsets, safety rules, recovery, and git-to-jj mapping

## Stop and ask

- the intended bookmark, remote, or push target is ambiguous
- the operation would rewrite, abandon, or publish someone else's work
- the operation would restore someone else's work
- the request requires `jj restore --to` / `jj restore --from` or reverting files you did not author without explicit written instruction
- it is unclear whether the user wants inspection only or a history-changing action
