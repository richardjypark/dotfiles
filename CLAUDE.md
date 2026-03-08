# CLAUDE.md

Chezmoi-managed dotfiles: Zsh + Oh My Zsh, Starship prompt (with jj support), Tmux with session persistence, and dev tools (NVM, uv, fzf, jj, Claude Code, Tailscale, delta, eza). See `README.md` for user-facing docs.

## Chezmoi Conventions

- Source: `~/.local/share/chezmoi/` (this repo) — Target: `~/`
- `dot_` prefix → `.`, `private_` prefix → 0600 permissions, `.tmpl` suffix → Go templates
- `.chezmoidata.toml` — template data (tool versions, npm packages)
- `.chezmoiversion.toml` — version pinning (fzf)
- `.chezmoiexternal.toml.tmpl` — external deps (Oh My Zsh, plugins, fzf, nvm) with 168h refresh
- `.chezmoi.toml` — chezmoi settings (git auto-commit, diff/merge tools)
- Templates use `{{ .nvm.version }}` syntax; test with `chezmoi execute-template < file.tmpl`

## Common Commands

```bash
chezmoi apply                       # Apply all changes
chezmoi apply --refresh-externals   # Force refresh external resources
chezmoi diff                        # See pending changes
chezmoi edit ~/.zshrc               # Edit in source directory
chezmoi status                      # Check status
VERBOSE=true chezmoi apply          # Scripts with verbose output
```

Aliases: `czu` (fetch + rebase + apply), `czuf` (+ externals + force), `czvc` (check pinned versions)

## Key Files

**Shell:** `dot_zshenv` (all shells: NVM/Bun/Cargo paths) · `dot_zshrc.tmpl` (interactive: Oh My Zsh, plugins, Starship) · `private_dot_config/starship.toml` (prompt config) · `private_dot_config/shell/*.sh` (modular: alias, env, fzf, history, path, profile, jj-fzf, gpg, zsh-fix, bat)

**Tmux:** `dot_tmux.conf` (config + TPM plugins). Auto-starts in `~/.zshrc`; skipped when `$SSH_TTY`, `$TERM_PROGRAM=vscode`, `$TMUX`, or `NOTMUX=1`.

**Scripts:** `.chezmoiscripts/run_{before,after}_NN-name.sh[.tmpl]` — all source `~/.local/lib/chezmoi-helpers.sh`, use state tracking (`~/.cache/chezmoi-state/`), quiet by default.

**Helpers:** `dot_local/private_lib/chezmoi-helpers.sh` — `vecho()`, `eecho()`, `state_exists()`/`mark_state()`, `is_installed()`, `ensure_sudo()`/`run_privileged()`.

## Operational Notes

- **Git auto-commit enabled** in source dir (`.chezmoi.toml`); no auto-push
- **State files:** clear `~/.cache/chezmoi-state/` to force script re-runs
- **External refresh:** weekly (168h); use `--refresh-externals` to force
- **Server role:** `CHEZMOI_ROLE=server chezmoi apply` skips Node/Bun/Homebrew/Ansible/Claude Code
- **Secrets:** untracked local env files only; see `docs/secrets-management.md`
- **Planning:** follow the canonical Codex planning workflow in `plans/README.md` for substantial work: deep-read first, write local-only `*-research.md` and `*-plan.md` artifacts, revise the plan from notes, and do not implement until the user approves the plan

## Version Control

Use `jj` (Jujutsu) instead of `git` for all VCS operations. Use the `/jj` skill for workflow details, commands, and revsets.

**Commit convention:** `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

## Skills

Invoke these skills for domain-specific tasks instead of working from memory:

| Skill | Use when |
|-------|----------|
| `/chezmoi-repo-maintainer` | Cross-cutting repo changes: docs, shell/tmux config, agent instructions, or multi-subsystem work |
| `/jj` | Commit, history, bookmarks, rebase, push — all jj workflows |
| `/chezmoi-script-maintainer` | Adding/modifying `.chezmoiscripts/` setup scripts |
| `/chezmoi-bootstrap-operator` | Running or updating bootstrap (Omarchy, VPS, lockdown) |
| `/dotfiles-version-refresh` | Bumping pinned versions across data/external/script files |

## See Also

- `AGENTS.md` — multi-agent safety rules and file management
- `ARCHITECTURE.md` — repo-wide invariants and change routing
- `README.md` — user-facing setup, profiles, and workflow docs
- `plans/README.md` — canonical research/plan workflow, file formats, and retention
- `docs/` — architecture, secrets, tooling, and skills reference
