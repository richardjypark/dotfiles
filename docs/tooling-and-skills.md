# Tooling And Skills

## Local Update Commands

- `czu`: jj-based dotfiles update and apply.
- `czuf`: forced jj-based update with externals/tool refresh.
- On macOS, uv setup is Homebrew-first during apply/refresh; pinned GitHub artifact install remains fallback when Homebrew is unavailable.
- `czvc`: managed `~/.local/bin/czvc` command that checks pinned versions and exits non-zero when API/network errors make the check incomplete.
- `czb`: managed `~/.local/bin/czb` command that bumps pinned versions with preflight/apply/verify transaction checks and rollback on failure.
- `czu`/`czuf` rebase to `[git].defaultBranch` from `.chezmoidata.toml` (with remote-head fallback) to avoid hardcoding branch names.
- Shell previews (`fzf`/`jj-fzf`) resolve `DOTFILES_BAT_CMD` to `bat` first, then `batcat` for Debian/Ubuntu compatibility.
- `private_dot_config/shell/bat.sh` sets conservative defaults when bat is available (`BAT_PAGER=less -RFK`, `BAT_STYLE=numbers,changes`).

Command definitions live under:

- `dot_local/bin/`
- `private_dot_config/shell/chezmoi.sh`
- `private_dot_config/shell/alias.sh`

## Agent Skills In This Repo

Skills are shared across both Claude Code and Codex CLI so that either tool follows the same repo conventions.

### Claude Code Skills (`~/.claude/skills/`)

Managed via `private_dot_claude/skills/`. Each skill has a `SKILL.md` with YAML frontmatter (`name`, `description`) and references shared Codex reference files by repo-relative path.

- `jj` — Jujutsu version control workflows (core concepts, daily flow, advanced workflows, revsets, config aliases, conflict resolution, safety rules, recovery, git-to-jj mapping).
- `chezmoi-script-maintainer` — Create and maintain `.chezmoiscripts/*` setup scripts. References `private_dot_codex/skills/chezmoi-script-maintainer/references/script-patterns.md`.
- `chezmoi-bootstrap-operator` — Bootstrap workflow operations across Omarchy and VPS paths. References `private_dot_codex/skills/chezmoi-bootstrap-operator/references/bootstrap-matrix.md`.
- `dotfiles-version-refresh` — Update pinned tool versions and external dependencies. References `private_dot_codex/skills/dotfiles-version-refresh/references/version-map.md`.

### Codex CLI Skills (`~/.codex/skills/`)

Managed via `private_dot_codex/skills/`. Each skill has a `SKILL.md`, an `agents/openai.yaml`, and optional `references/` directory with detailed reference files.

- `jj` — Jujutsu version control workflows (same content as Claude Code version).
- `chezmoi-script-maintainer` — Script creation patterns with `references/script-patterns.md`.
- `chezmoi-bootstrap-operator` — Bootstrap flows with `references/bootstrap-matrix.md`.
- `dotfiles-version-refresh` — Version pinning with `references/version-map.md`.

### Reference Sharing

Canonical reference files live under `private_dot_codex/skills/*/references/`. Claude Code skills cross-reference these by repo-relative path since both tools operate from `~/.local/share/chezmoi`.

## Future Machine Combination Pattern

Use this pattern for maintainability:

1. Add role/profile behavior first (template/script conditions).
2. Keep shared helper logic in `dot_local/private_lib/chezmoi-helpers.sh`.
3. Keep machine-specific exceptions minimal and documented.
4. Prefer adding pinned version data in `.chezmoidata.toml` and `.chezmoiversion.toml` over ad hoc script constants.
