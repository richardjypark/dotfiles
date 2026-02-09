# AGENTS.md

Agent operating guide for this dotfiles repository.
Applies to coding CLIs such as Codex, OpenCode, and similar terminal agents.

## Mission

Maintain this chezmoi source repo safely and predictably.
Prioritize idempotent setup behavior, secure defaults, and minimal-risk edits.

## Repository Context

- Repo path: `~/.local/share/chezmoi`
- This is the chezmoi source of truth; files are rendered to `~/`
- `dot_*` maps to `.*` in home (example: `dot_tmux.conf` -> `~/.tmux.conf`)
- `private_*` maps to target with restrictive permissions
- `*.tmpl` are Go templates rendered with `.chezmoidata.toml`
- Setup scripts live in `.chezmoiscripts/`

## First Steps for Any Task

1. Read `README.md` for current bootstrap, role/profile, and workflow expectations.
2. Check current tree status before editing: `git status --short`.
3. Prefer changing chezmoi source files, not rendered files in `~/`.
4. Keep edits scoped to the request; do not refactor unrelated areas.

## Core Working Rules

- Use `rg`/`rg --files` for discovery.
- Prefer small, reviewable patches.
- Preserve existing style and script conventions.
- Never hardcode secrets, tokens, hostnames, or private keys.
- Do not weaken security defaults in bootstrap/hardening scripts unless explicitly requested.

## Multi-Agent Safety & File Management

- Delete unused or obsolete files when your changes make them irrelevant (refactors, feature removals, etc.), and revert files only when the change is yours or explicitly requested.
- If a git or jj operation leaves you unsure about other agents' in-flight work, stop and coordinate instead of deleting.
- Before attempting to delete a file to resolve a local type/lint failure, stop and ask the user. Other agents are often editing adjacent files; deleting their work to silence an error is never acceptable without explicit approval.
- NEVER edit `.env` or any environment variable files—only the user may change them.
- Coordinate with other agents before removing their in-progress edits—don't revert or delete work you didn't author unless everyone agrees.
- Moving/renaming and restoring files is allowed.
- ABSOLUTELY NEVER run destructive git operations (e.g., `git reset --hard`, `rm`, `git checkout`/`git restore` to an older commit) or destructive jj operations (e.g., `jj abandon --deleted`, `jj restore` with `--to`/`--from` targeting old revisions) unless the user gives an explicit, written instruction in this conversation.
- Treat these commands as catastrophic; if you are even slightly unsure, stop and ask before touching them.
- Never use `git restore` (or similar commands) or `jj restore` to revert files you didn't author—coordinate with other agents instead so their in-progress work stays intact.
- Always double-check `git status` or `jj status` before any commit or describe.
- Keep commits atomic: commit only the files you touched and list each path explicitly.
  - For git: for tracked files run `git commit -m "<scoped message>" -- path/to/file1 path/to/file2`.
  - For brand-new files, use the one-liner `git restore --staged :/ && git add "path/to/file1" "path/to/file2" && git commit -m "<scoped message>" -- path/to/file1 path/to/file2`.
  - For jj: use `jj describe -m "<scoped message>"` on the specific change, or `jj new` with specific paths.
- Quote any paths containing brackets or parentheses (e.g., `src/app/[candidate]/**`) when staging, committing, or adding so the shell does not treat them as globs or subshells.
- When running `git rebase` or `jj rebase`, avoid opening editors—export `GIT_EDITOR=:` and `GIT_SEQUENCE_EDITOR=:` (or pass `--no-edit`) so the default messages are used automatically.
- Never amend commits (`git commit --amend` or `jj describe` followed by `jj squash` on ancestors) unless you have explicit written approval in the task thread.

## Chezmoi-Specific Rules

- Edit source files in this repo, then apply with chezmoi.
- Typical verification path: `chezmoi diff` -> `chezmoi apply` -> `chezmoi status`
- Use `chezmoi apply --refresh-externals` when changes affect `.chezmoiexternal.toml.tmpl` or pinned external artifacts.
- Role/profile-aware behavior matters.
- Server path: `CHEZMOI_ROLE=server`
- Omarchy skip profile: `CHEZMOI_PROFILE=omarchy`

## Script Conventions (`.chezmoiscripts`)

- Scripts must be idempotent.
- Respect state tracking under `~/.cache/chezmoi-state`.
- Keep default output quiet; use existing verbose patterns (`vecho`) and essential output (`eecho`).
- Guard network/remote installer behavior behind explicit trust gates where applicable.
- Follow existing naming/order convention (`run_before_*`, `run_after_*`).

## High-Impact Files

- `.chezmoidata.toml` for template data and pinned runtime values
- `.chezmoiversion.toml` for version pins
- `.chezmoiexternal.toml.tmpl` for external resources and refresh behavior
- `scripts/bootstrap-omarchy.sh` for Omarchy bootstrap flow
- `bootstrap-vps.sh` for Debian/Ubuntu VPS bootstrap and hardening
- `scripts/server-lockdown-tailscale.sh` for SSH lockdown posture
- `dot_zshrc.tmpl` and `dot_tmux.conf` for daily shell/tmux behavior

## Validation Checklist After Edits

1. Run targeted lint/check commands if available.
2. Run `chezmoi diff` and verify only intended changes render.
3. Run `chezmoi apply` successfully.
4. If shell changed, run `zsh -n ~/.zshrc`.
5. If tmux config changed, run `tmux source-file ~/.tmux.conf`.
6. Summarize what changed, risks, and any manual follow-up.

## Common Task Shortcuts

- Apply all changes: `chezmoi apply`
- Show pending: `chezmoi diff`
- Update from repo + apply: `chezmoi update`
- Enter source dir: `chezmoi cd`
- Omarchy workstation bootstrap: `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation`
- Omarchy server bootstrap: `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server`

## Commit Guidance

- Keep commits atomic and task-focused.
- Explain behavioral impact in commit message body when changing bootstrap/scripts.
- Include validation evidence in PR/summary notes when possible.

## Reference Docs

- `README.md` for user-facing workflows and current bootstrap docs
- `CLAUDE.md` for additional repo context and historical agent notes
