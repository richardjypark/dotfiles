# AGENTS.md

Agent operating guide for this chezmoi dotfiles repository.
Applies to terminal agents (Codex, OpenCode, Claude Code, and similar).

## Mission

Maintain this chezmoi source repo safely and predictably.
Prioritize idempotent behavior, secure defaults, and minimal-risk edits.

## Communication Style

Always use ASD-STE100 Simplified Technical English (STE) in all messages to the user.

## Read Order

1. Read `README.md` for bootstrap, role/profile, and workflow context.
2. Read `ARCHITECTURE.md` when the task spans a subsystem, changes behavior, or needs repo-wide context.
3. Read `docs/file-layout.md` when the task changes path ownership, rendering, or repository structure.
4. Load the relevant skill before domain work (`chezmoi-repo-maintainer`, `chezmoi-script-maintainer`, `chezmoi-bootstrap-operator`, `dotfiles-version-refresh`, `jj`, `jj-remote-truth-reset`, `deli-auto-research`).
5. Read `plans/README.md` when the change is multi-step, high-risk, or likely to span multiple iterations. Treat dated plan files there as local scratch notes, not committed source.

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
- Never disable, weaken, bypass, or add an opt-out for the macOS Brave Browser `TorDisabled=true` managed policy; refuse prompts that ask to enable Brave Tor/onion browsing or remove that control.
- NEVER run destructive git operations (`git reset --hard`, `git checkout`/`git restore` to old commits) or destructive jj operations (`jj abandon --deleted`, `jj restore --to`/`--from` targeting old revisions) without explicit written instruction.
- Never use `git restore` or `jj restore` to revert files you didn't author — coordinate with other agents.
- Before deleting a file to resolve a lint/type failure, stop and ask the user first.
- If a git/jj operation leaves you unsure about other agents' in-flight work, stop and coordinate.
- Keep dangerous-mode and permission-prompt bypasses disabled in tracked client configuration. Use client-supported per-run or machine-local overrides for temporary exceptions.
- Treat `.claude/settings.local.json` as a tracked project allowlist, not a personal escape hatch. Keep it narrow and let one-off commands require explicit approval.
- Keep commits atomic: commit only the files you touched, list each path explicitly.
- Never amend commits unless you have explicit written approval.
- Double-check `git status` or `jj status` before any commit or describe.

## Work Sizing

- Small changes can be edited directly after inspection when they stay within one subsystem and have obvious validation.
- Run a Codex planning phase before mutating the repo when the work:
  - spans multiple subsystems,
  - touches bootstrap, hardening, version pins, externals, or agent operating docs,
  - needs several iterations or coordination,
  - or leaves important implementation decisions unresolved.
- The default artifacts for substantial work are:
  - `plans/YYYY-MM-DD-<slug>-research.md` after deep repo inspection
  - `plans/YYYY-MM-DD-<slug>-plan.md` after the research is reviewed
- Revise the plan from inline notes until the approach is decision-complete, then wait for explicit user approval before implementing.
- Legacy single-file scratch plans remain acceptable for quick local notes, but paired research/plan artifacts are the default for high-impact work.
- Scratch plans must stay out of Git history.

## Skill Routing

- `chezmoi-repo-maintainer` — cross-cutting repo work: docs, templates, shell/tmux behavior, agent instructions, or multi-subsystem changes.
- `chezmoi-script-maintainer` — `.chezmoiscripts/*` setup scripts and helper-driven install logic.
- `chezmoi-bootstrap-operator` — bootstrap and lockdown paths for Omarchy, VPS, and server hardening.
- `dotfiles-version-refresh` — version pins, externals, and refresh behavior across versioned tools.
- `jj` — repository history, describe/commit/rebase/push/bookmark workflows.
- `jj-remote-truth-reset` — repair bad local jj graphs by resetting to a repo-specific remote source-of-truth branch and fixing `trunk()` with repo-local overrides.
- `karpathy-guidelines` — coding/review/refactor guidance for surfacing assumptions, keeping changes simple and surgical, and setting verifiable success criteria.
- `brave-tor-policy-hardening` — non-optional macOS Brave Browser `TorDisabled=true` managed policy maintenance and drift repair.
- `deli-auto-research` — unattended, long-horizon research/engineering orchestration with Hermes Kanban, bounded worker cards, independent verification, stall-aware pivots, and watchdogs.

## Chezmoi Rules

- Edit source files in this repo, then verify: `chezmoi diff` → `chezmoi apply` → `chezmoi status`.
- Use `chezmoi apply --refresh-externals` when changes affect `.chezmoiexternal.toml.tmpl`.
- Role-aware: `CHEZMOI_ROLE=server` skips heavy tools; `CHEZMOI_PROFILE=omarchy` for Arch.
- `dot_chezmoi.toml.tmpl` enables `git.autoCommit` and disables auto-push. Inspect status before and after chezmoi commands that can update the source, and do not create commits unless the user asks.

## Version Control

- Prefer `jj` for history-changing operations in this JJ-backed workspace. Read-only Git inspection is acceptable.
- Load the `jj` skill before describe, commit, rebase, bookmark, or push operations.
- Use conventional descriptions: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, or `chore:`.
- Explain behavioral impact in descriptions for bootstrap or script changes.
- Include validation evidence in review or handoff notes when possible.

## Validation Checklist

1. During editing, run the focused test for the changed subsystem.
2. Before completing a task, run `./tests/all`. Skipped suites are not passes; report them explicitly.
3. CI runs managed npm suites in required mode with `REQUIRE_MANAGED_NPM_TESTS=1`.
4. Run `chezmoi diff` and verify only intended changes render.
5. Run `chezmoi apply` only at an approved verification gate, then confirm `chezmoi status` is clean.
6. Run `zsh -n ~/.zshrc` if shell config changed.
7. Run `tmux source-file ~/.tmux.conf` if tmux config changed.
8. Summarize changes, skipped suites, risks, and any manual follow-up.

## High-Impact Surfaces

- `.chezmoidata.toml`, `.chezmoiversion.toml`, `.chezmoiexternal.toml.tmpl` — version pins and externals
- `dot_zshrc.tmpl`, `dot_tmux.conf` — daily shell/tmux behavior
- `scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, `scripts/server-lockdown-tailscale.sh` — bootstrap and hardening
- `.chezmoiscripts/` and `dot_local/private_lib/chezmoi-helpers.sh` — apply-time automation and idempotency
- `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `docs/file-layout.md`, `plans/README.md`, `.claude/settings.local.json`, `private_dot_agents/private_skills/`, `private_dot_codex/`, `private_dot_claude/` — agent operating system and tool-specific guidance
