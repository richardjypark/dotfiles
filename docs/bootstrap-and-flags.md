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

Base package set includes `bat`, `git-delta`, `eza`, and `gh` so preview/diff/list
replacements and GitHub CLI workflows work immediately on Omarchy hosts.

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

Bootstrap installs `bat`, then attempts `git-delta`/`delta` and `eza`/`exa` from apt
repositories when available. Runtime shell config auto-detects command-name variants
(`bat`/`batcat`, `eza`/`exa`).

## Role/Profile Behavior

Canonical expansion model:

1. Primary axis: `CHEZMOI_ROLE` (`workstation`, `server`)
2. Secondary axis: `CHEZMOI_PROFILE` (example: `omarchy`)
3. Hostname-specific checks: legacy fallback only (new logic should prefer role/profile)

Use role/profile conditions in templates/scripts before adding hostname-specific logic.

## Update Helper Commands

`czu`, `czuf`, `czl`, and `czm` are managed wrapper commands installed to `~/.local/bin`.

- `czu`/`czuf` resolve one canonical source workspace from `CHEZMOI_SOURCE_DIR`, backward-compatible `CHEZMOI_DIR`, or `chezmoi source-path`. The selected path must be an absolute existing JJ workspace root containing `.chezmoidata.toml`; resolution fails closed instead of silently using `$HOME/.local/share/chezmoi`.
- `czu`/`czuf` call `jj-sync-trunk --remote origin` for authoritative remote-head detection and durable repo-local `trunk()` repair, then rebase the current change onto `trunk()`. They do not duplicate fetch/default-branch parsing.
- on Omarchy hosts, if `CHEZMOI_PROFILE` is unset, wrappers default it to `omarchy`
- `czuf` adds `TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1` and applies the same selected source with `--refresh-externals --force`; it does not run broad package-manager upgrades or bump source pins
- `czl` is the Omarchy/Arch daily maintenance wrapper. No arguments run the compatible full workflow: require a clean current JJ change, run `czuf`, upgrade official Arch packages with `sudo pacman -Syu --noconfirm`, atomically run `chezmoi-bump --all`, and force a final selected-source apply so Arch converges to the stable pins. `--system-only` skips the bump but preserves the final convergence apply.
- `czm` is the macOS daily maintenance wrapper. No arguments require a clean current JJ change, run `czuf` with `CHEZMOI_MACOS_MAINTENANCE_MODE=1`, perform the existing Homebrew/greedy-cask upgrades, atomically run `chezmoi-bump --all`, and use a post-bump JJ summary to decide whether a final selected-source apply is needed. `--system-only` skips the bump and final pin apply. `brew cleanup` runs last and warns rather than failing an otherwise successful maintenance run.
- `czl` and `czm` accept `--bump-pins` as an explicit synonym for full maintenance, `--plan` for a non-installing preview, `--verbose` for synchronization/command traces, and `--help`. `--system-only` conflicts with `--bump-pins`; unknown arguments exit 2.
- full pin-bump mode rejects a dirty current JJ change before sudo, package-manager, or source mutation. System-only and plan modes permit dirty source.
- plan mode performs no fetch/rebase/config write, package installation, tracked-source mutation, or destination apply. It may perform network reads/cache writes while running `jj-sync-trunk --dry-run --no-fetch`, `chezmoi diff`, read-only package checks, and `chezmoi-bump --dry-run --all --force`.
- `chezmoi-bump --all` owns an invocation-level transaction across generic and Pi source targets. A later dependency failure or catchable signal restores every snapshot and releases the private `${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-maintenance/chezmoi-bump` lock. Ambiguous stale locks are reported, not auto-removed.
- `chezmoi-bump pi` resolves to the newest `@earendil-works/pi-coding-agent` version that already satisfies `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS`
