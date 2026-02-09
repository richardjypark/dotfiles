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
- Do not use destructive git operations (`reset --hard`, checkout of unrelated files).
- If unrelated workspace changes appear, do not revert them.

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
