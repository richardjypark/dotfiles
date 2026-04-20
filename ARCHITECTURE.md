# Architecture

This repo is the source of truth for a chezmoi-managed home directory. The design goal is predictable `chezmoi apply`: source-driven, repeatable, role-aware, and secure by default.

## Core Invariants

- Edit source files in this repo, not rendered files in `~/`.
- Keep `chezmoi apply` idempotent; repeated runs should converge quickly.
- Preserve secure defaults in bootstrap and hardening flows unless the user explicitly asks otherwise.
- Keep secrets and machine-specific private values out of tracked files.
- Prefer changing shared data and templates before hardcoding behavior in multiple scripts.

## System Model

1. Source files live in this repo as chezmoi templates, scripts, docs, and skills.
2. `chezmoi` renders those sources into the home directory.
3. `.chezmoiscripts/*` run around apply and install/configure tools.
4. Scripts depend on `dot_local/private_lib/chezmoi-helpers.sh` plus state markers in `~/.cache/chezmoi-state`; use `chezmoi-rerun-script <source-script-path>` when you need to invalidate one remembered `run_onchange_*` step without clearing all state.
5. Shell, tmux, jj, and helper commands are layered on top of that rendered state.

## Subsystems

### Bootstrap and Hardening

- Entry points: `scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, `scripts/server-lockdown-tailscale.sh`
- Responsibility: first-run machine setup, package bootstrapping, secure server posture
- Constraints: non-interactive by default, explicit trust gates for remote installers, phased server hardening

### Template Data and Externals

- Key files: `.chezmoidata.toml`, `.chezmoiversion.toml`, `.chezmoiexternal.toml.tmpl`
- Responsibility: version pins, template inputs, external dependency revisions
- Constraints: keep pins deterministic and refresh behavior consistent with installer logic

### Apply-Time Setup Scripts

- Key files: `.chezmoiscripts/run_onchange_before_*`, `.chezmoiscripts/run_onchange_after_*`, and the small set of always-run `.chezmoiscripts/run_after_*` follow-up scripts
- Responsibility: install and configure tools during `chezmoi apply`
- Constraints: helper-driven, quiet by default, state-aware, role/profile aware

### Interactive Environment

- Key files: `dot_zshrc.tmpl`, `dot_tmux.conf`, `private_dot_config/shell/*`, `private_dot_config/jj/*`
- Responsibility: daily shell/tmux/editor/version-control behavior
- Constraints: preserve existing UX patterns, validate changed targets after render

### Agent Operating System

- Key files: `AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `plans/README.md`, `.claude/settings.local.json`, `private_dot_agents/private_skills/`, `private_dot_codex/`, `private_dot_claude/`
- Responsibility: tell agents how to inspect, plan, edit, validate, and hand off work in this repo
- Constraints: keep root instructions short, push detail into deeper docs/skills, keep `private_dot_agents/private_skills/` as the canonical skill source tree, and treat `private_dot_codex/` / `private_dot_claude/` as client-routing or client-config surfaces unless a tool-specific difference is intentional

## Dependency Direction

- Data/version files feed templates and scripts; prefer updating them before duplicating constants elsewhere.
- `dot_local/private_lib/chezmoi-helpers.sh` is the shared contract for setup scripts.
- Runtime docs (`README.md`, `docs/`) explain user workflows; agent docs (`AGENTS.md`, skills, `plans/README.md`) explain implementation workflows.
- Skills should reference deeper docs or references instead of duplicating long repo context.

## Change Routing

| If changing... | Inspect first | Validate with... |
| --- | --- | --- |
| Bootstrap or hardening behavior | `README.md`, bootstrap scripts, `chezmoi-bootstrap-operator` | `bash -n` on touched scripts, then `chezmoi diff` / `apply` / `status` |
| `.chezmoiscripts/*` behavior | adjacent scripts, helper library, `chezmoi-script-maintainer` | `bash -n` or `chezmoi execute-template ... | bash -n`, then `chezmoi diff` / `apply` / `status` |
| Version pins or externals | pin files, relevant setup scripts, `dotfiles-version-refresh` | template render checks, `chezmoi apply --refresh-externals`, then `chezmoi status` |
| Shell or tmux behavior | `dot_zshrc.tmpl`, `dot_tmux.conf`, relevant `private_dot_config/*` files | `chezmoi diff` / `apply` / `status`, then `zsh -n ~/.zshrc` and/or `tmux source-file ~/.tmux.conf` |
| Agent docs, skills, or Codex/Claude config | `AGENTS.md`, `CLAUDE.md`, `docs/tooling-and-skills.md`, `.claude/settings.local.json`, `private_dot_agents/private_skills/`, `private_dot_codex/`, `private_dot_claude/` | link/reference review, then `chezmoi diff` / `apply` / `status` |

## Plan Before Editing When

- The change spans more than one subsystem.
- The work touches bootstrap, hardening, agent operating docs, version pins, or externals.
- The implementation needs multiple phases, multiple tools, or coordination with other agents.
- The success criteria or validation path are not obvious at the start.

Use `plans/README.md` for the canonical planning flow: deep repo read, `*-research.md`, `*-plan.md`, annotation/revision, approval gate, then implementation.

## Deep Dives

- `docs/architecture-and-performance.md`
- `docs/bootstrap-and-flags.md`
- `docs/tooling-and-skills.md`
- `docs/secrets-management.md`
