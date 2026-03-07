# AGENTS.md

Agent operating guide for this chezmoi dotfiles repository.
Applies to terminal agents (Codex, OpenCode, Claude Code, and similar).

## Mission

Maintain this chezmoi source repo safely and predictably.
Prioritize idempotent behavior, secure defaults, and minimal-risk edits.

## Read Order

1. Read `README.md` for bootstrap, role/profile, and workflow context.
2. Read `ARCHITECTURE.md` when the task spans a subsystem, changes behavior, or needs repo-wide context.
3. Load the relevant skill before domain work (`chezmoi-repo-maintainer`, `chezmoi-script-maintainer`, `chezmoi-bootstrap-operator`, `dotfiles-version-refresh`, `jj`).
4. Read `plans/README.md` when the change is multi-step, high-risk, or likely to span multiple iterations. Treat dated plan files there as local scratch notes, not committed source.

## First Pass

1. Check tree status before editing: `jj status` or `git status --short`.
2. Prefer chezmoi source files in this repo over rendered files in `~/`.
3. Use `rg` / `rg --files` for discovery; inspect likely sources of truth before asking questions.
4. Keep edits scoped to the request; avoid unrelated refactors.
5. Re-check `jj status` or `git status --short` before any commit or `jj describe`.

## Repo-Local Precedence

When repo-local instructions conflict, prefer:

1. The user's current request.
2. Safety rules in this file.
3. The most relevant skill workflow.
4. Local file conventions or inline comments.

Higher-level harness/system instructions still take precedence over this file.

## Safety Rules

- Never hardcode secrets, tokens, hostnames, or private keys.
- NEVER edit `.env` or environment variable files — only the user may change them.
- Do not weaken security defaults in bootstrap/hardening scripts unless explicitly requested.
- NEVER run destructive git operations (`git reset --hard`, `git checkout`/`git restore` to old commits) or destructive jj operations (`jj abandon --deleted`, `jj restore --to`/`--from` targeting old revisions) without explicit written instruction.
- Never use `git restore` or `jj restore` to revert files you didn't author — coordinate with other agents.
- Before deleting a file to resolve a lint/type failure, stop and ask the user first.
- If a git/jj operation leaves you unsure about other agents' in-flight work, stop and coordinate.
- Keep commits atomic: commit only the files you touched, list each path explicitly.
- Never amend commits unless you have explicit written approval.
- Double-check `git status` or `jj status` before any commit or describe.

## Work Sizing

- Small changes can be edited directly after inspection when they stay within one subsystem and have obvious validation.
- Create or update a local-only `plans/YYYY-MM-DD-<slug>.md` scratch plan before mutating the repo when the work:
  - spans multiple subsystems,
  - touches bootstrap, hardening, version pins, externals, or agent operating docs,
  - needs several iterations or coordination,
  - or leaves important implementation decisions unresolved.
- Scratch plans should capture goal, findings, implementation decisions, validation steps, and current status, but they must stay out of Git history.

## Skill Routing

- `chezmoi-repo-maintainer` — cross-cutting repo work: docs, templates, shell/tmux behavior, agent instructions, or multi-subsystem changes.
- `chezmoi-script-maintainer` — `.chezmoiscripts/*` setup scripts and helper-driven install logic.
- `chezmoi-bootstrap-operator` — bootstrap and lockdown paths for Omarchy, VPS, and server hardening.
- `dotfiles-version-refresh` — version pins, externals, and refresh behavior across versioned tools.
- `jj` — repository history, describe/commit/rebase/push/bookmark workflows.

## Chezmoi Rules

- Edit source files in this repo, then verify: `chezmoi diff` → `chezmoi apply` → `chezmoi status`.
- Use `chezmoi apply --refresh-externals` when changes affect `.chezmoiexternal.toml.tmpl`.
- Role-aware: `CHEZMOI_ROLE=server` skips heavy tools; `CHEZMOI_PROFILE=omarchy` for Arch.

## Validation Checklist

1. `bash -n` on edited shell scripts (or `chezmoi execute-template < file.tmpl | bash -n` for templates).
2. `chezmoi diff` — verify only intended changes render.
3. `chezmoi apply` — confirm it succeeds.
4. `zsh -n ~/.zshrc` if shell config changed.
5. `tmux source-file ~/.tmux.conf` if tmux config changed.
6. Summarize changes, risks, and any manual follow-up.

## High-Impact Surfaces

- `.chezmoidata.toml`, `.chezmoiversion.toml`, `.chezmoiexternal.toml.tmpl` — version pins and externals
- `dot_zshrc.tmpl`, `dot_tmux.conf` — daily shell/tmux behavior
- `scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, `scripts/server-lockdown-tailscale.sh` — bootstrap and hardening
- `.chezmoiscripts/` and `dot_local/private_lib/chezmoi-helpers.sh` — apply-time automation and idempotency
- `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `plans/README.md`, `private_dot_codex/skills/`, `private_dot_claude/skills/` — agent operating system and tool-specific guidance

## Commit Guidance

- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Explain behavioral impact in commit body when changing bootstrap or scripts.
- Include validation evidence in PR/summary notes when possible.
