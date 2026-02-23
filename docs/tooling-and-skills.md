# Tooling And Skills

## Local Update Commands

- `czu`: jj-based dotfiles update and apply.
- `czuf`: forced jj-based update with externals/tool refresh.
- On macOS, uv setup is Homebrew-first during apply/refresh; pinned GitHub artifact install remains fallback when Homebrew is unavailable.
- `czvc`: checks pinned versions.
- `czb`: bumps pinned versions with preflight/apply/verify transaction checks and rollback on failure.
- `czu`/`czuf` rebase to `[git].defaultBranch` from `.chezmoidata.toml` (with remote-head fallback) to avoid hardcoding branch names.

Command definitions live under:

- `private_dot_config/shell/chezmoi.sh`
- `private_dot_config/shell/alias.sh`

## Agent Skills In This Repo

Available local skills include:

- `chezmoi-bootstrap-operator`
- `chezmoi-script-maintainer`
- `dotfiles-version-refresh`
- `jj`

These are installed under `~/.codex/skills` and are intended to keep bootstrap/script/version changes consistent with repo conventions.

## Future Machine Combination Pattern

Use this pattern for maintainability:

1. Add role/profile behavior first (template/script conditions).
2. Keep shared helper logic in `dot_local/private_lib/chezmoi-helpers.sh`.
3. Keep machine-specific exceptions minimal and documented.
4. Prefer adding pinned version data in `.chezmoidata.toml` and `.chezmoiversion.toml` over ad hoc script constants.
