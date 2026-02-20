# Bootstrap And Flags

This document is the detailed reference behind the quick commands in `README.md`.

## Omarchy Bootstrap

Script: `scripts/bootstrap-omarchy.sh`

```bash
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server
```

Flags:

- `--role workstation|server` (required)
- `--repo <chezmoi-repo>` (optional, default `richardjypark`)

Environment:

- `PRIVATE_ENV_FILE` (default `~/.config/dotfiles/bootstrap-private.env`)
- `TRUST_ON_FIRST_USE_INSTALLERS=1` (required for remote installer/download paths)
- `DOTFILES_REPO` (alternate repo selector)
- `CHEZMOI_PREFETCH_JOBS` (default `4`)
- `CHEZMOI_DOWNLOAD_CACHE_DIR` (default `~/.cache/chezmoi-downloads`)

## Debian/Ubuntu VPS Bootstrap

Script: `bootstrap-vps.sh`

Expected posture:

- no passwordless sudo by default
- no root key copy by default
- no automatic remote installers unless explicitly trusted

Common env vars:

- `USERNAME`
- `DOTFILES_REPO`
- `TRUST_ON_FIRST_USE_INSTALLERS=1`
- `ALLOW_PASSWORDLESS_SUDO=1` (opt-in)
- `COPY_ROOT_AUTH_KEYS=1` (opt-in)
- `LOCK_SSH_TO_TAILSCALE=1` (post-verification hardening)
- `DISABLE_ROOT_LOGIN=1` (post-verification hardening)

## Role/Profile Behavior

Canonical expansion model:

1. Primary axis: `CHEZMOI_ROLE` (`workstation`, `server`)
2. Secondary axis: `CHEZMOI_PROFILE` (example: `omarchy`)
3. Hostname-specific checks: legacy fallback only (new logic should prefer role/profile)

Use role/profile conditions in templates/scripts before adding hostname-specific logic.

## Update Helper Commands

`czu` and `czuf` are managed wrapper commands installed to `~/.local/bin`.

- `czu`/`czuf` choose the rebase target from `.chezmoidata.toml` `[git].defaultBranch`, then fallback to the Git remote default branch, then `master`
- on Omarchy hosts, if `CHEZMOI_PROFILE` is unset, wrappers default it to `omarchy`
- `czuf` adds `TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1` and runs `chezmoi apply --refresh-externals --force`
