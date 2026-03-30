# github.com/richardjypark/dotfiles

Dotfiles managed with [chezmoi](https://github.com/twpayne/chezmoi).

## Fresh Machine Install

### Omarchy / Arch (personal machine or server)

```bash
sudo pacman -S --noconfirm --needed chezmoi git curl
chezmoi init --apply richardjypark
```

Run role bootstrap:

```bash
# Personal workstation
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation

# Personal server
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server
```

For server hardening (after confirming Tailscale SSH access):

```bash
sudo ~/.local/share/chezmoi/scripts/server-lockdown-tailscale.sh
```

### Debian / Ubuntu VPS

Clone and run as root (or with sudo) on a fresh VPS:

```bash
git clone https://github.com/richardjypark/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
USERNAME="$USER" DOTFILES_REPO="https://github.com/richardjypark/dotfiles.git" TRUST_ON_FIRST_USE_INSTALLERS=1 bash ./bootstrap-vps.sh
```

### macOS (workstation)

```bash
brew install chezmoi git curl
chezmoi init --apply richardjypark
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

## Update Commands

| Command | What it does | When to use |
| --- | --- | --- |
| `chezmoi update` | Pulls latest dotfiles from upstream and applies them. | Standard sync from repo changes. |
| `czu` | Managed wrapper command in `~/.local/bin/czu`: runs `jj fetch` + `jj rebase -d <default-branch>` (from `.chezmoidata.toml` `[git].defaultBranch`, with remote-head fallback), defaults `CHEZMOI_PROFILE=omarchy` on Omarchy hosts when unset, then runs `chezmoi apply`. | Daily update when you want the jj-based workflow. |
| `czuf` | Managed wrapper command in `~/.local/bin/czuf`: same as `czu`, plus `TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1 chezmoi apply --refresh-externals --force`. | Full refresh when pinned tools/externals changed or state needs rebuilding (macOS uses Homebrew-first `uv`, with pinned artifact fallback). |
| `czl` | Managed wrapper command in `~/.local/bin/czl`: fail-fast Omarchy/Arch workflow that refreshes sudo credentials, runs `czuf`, upgrades official Arch packages with `pacman -Syu`, updates the globally installed Pi Coding Agent via npm when present, runs `chezmoi-bump --all`, then re-runs `chezmoi apply --refresh-externals --force` so the machine converges to the newly bumped stable pins. | Single-command daily maintenance on Omarchy/Arch Linux. |
| `czm` | Managed wrapper command in `~/.local/bin/czm`: fail-fast macOS workflow that runs `czuf` in a Homebrew-maintenance mode, then `brew update` + `brew upgrade` + `brew upgrade --cask --greedy` + `brew cleanup`, then `chezmoi-bump --all`, then re-runs `chezmoi apply --refresh-externals --force` only when bumped pins changed tracked source files. | Single-command daily maintenance on macOS. |
| `czvc` | Managed wrapper command in `~/.local/bin/czvc`: runs `chezmoi-check-versions` and exits non-zero when API/network errors make results incomplete. | Check pinned versions against upstream releases. |
| `czb` | Managed wrapper command in `~/.local/bin/czb`: runs `chezmoi-bump` with fail-closed transaction checks (preflight -> apply -> verify -> rollback on failure). | Bump pinned dependency versions safely. |
| `chezmoi-rerun-script <source-script-path>` | Managed helper in `~/.local/bin/chezmoi-rerun-script`: clears chezmoi's remembered `run_onchange_*` state for the given source script so the next `chezmoi apply` reruns it. | Recover from manual deletions or force a one-off rerun of a bootstrap/setup script after local drift. |

`cz*` commands are installed in `~/.local/bin` and do not rely on shell aliases.
Aliases in `~/.config/shell/alias.sh` are convenience shortcuts only.
Repo-managed `jj fetch` is intentionally quiet (`jj git fetch --quiet`); run raw `jj git fetch` when you want rebase/abandon diagnostics.

Shell preview behavior:
- `fzf` and `jj-fzf` previews prefer `bat` and auto-fallback to `batcat` on Debian/Ubuntu-style installs.
- If neither command is available, previews degrade to plain output until `bat` is installed.
- `jji`/`jjfi` diff rendering prefers `delta`, with fallback to `bat`/`batcat`, then plain `less` output.
- Interactive shell aliases map `ls`/`ll`/`la`/`lt` to `eza` (or `exa` fallback) when installed.
- Interactive shell aliases map `diff` to `delta` when installed.
- Git pager and interactive patch diff filtering prefer `delta` and fall back to `less`/plain output when missing.

`chezmoi-bump` safety/debug flags:
- `--manifest-out <path>` writes the computed transaction manifest (multi-dep runs emit one file per dep).
- `--no-strict` relaxes post-apply verification (strict is default).
- `--no-rollback` keeps mutated files on failure for debugging (rollback is default).

## Role + Profile Matrix

| Dimension | Value | Effect |
| --- | --- | --- |
| `CHEZMOI_ROLE` | `workstation` | Full personal workstation toolchain. |
| `CHEZMOI_ROLE` | `server` | Server-focused setup, skips workstation-only tooling. |
| `CHEZMOI_PROFILE` | `omarchy` | Skip managed shell/terminal targets and keep local Omarchy files. |

Examples:

```bash
CHEZMOI_ROLE=server chezmoi update
CHEZMOI_PROFILE=omarchy chezmoi update
CHEZMOI_ROLE=server TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

## Tmux Multi-Host Status Badges

Tmux renders two host badges on the right side:
- Context badge: `LOCAL`, `SSH`, or `REMOTE`
- Host alias badge: short alias with per-host color

Alias mappings are sourced from:

```bash
~/.config/tmux/host-aliases.conf
```

This file is managed by chezmoi source:

```bash
private_dot_config/tmux/private_host-aliases.conf.tmpl
```

Format:

```text
raw_host|alias|fg|bg
```

Guidance:
- Use neutral aliases (for example: `home`, `cloud`, `lab`)
- Do not use IP addresses; IP-based SSH targets are masked in status badges
- Keep host labels short to avoid status truncation

## Optional Private Bootstrap Inputs

Create a local untracked env file for machine-specific values:

```bash
mkdir -p ~/.config/dotfiles
cp ~/.local/share/chezmoi/scripts/bootstrap-private-env.example ~/.config/dotfiles/bootstrap-private.env
chmod 600 ~/.config/dotfiles/bootstrap-private.env
$EDITOR ~/.config/dotfiles/bootstrap-private.env
```

## Pi Maintenance Agent

The pi maintenance agent can be tracked in this repo without activating on every machine.
It is only supported on Omarchy hosts/profiles; non-Omarchy machines ignore the rendered source/systemd units to avoid conflicts.

Opt in only on Omarchy hosts that should run it:

```bash
mkdir -p ~/.config/dotfiles
touch ~/.config/dotfiles/pi-maintenance-agent.enabled
cp ~/.local/share/pi-maintenance-agent/config/runtime.env.example ~/.config/dotfiles/pi-maintenance-agent.env
chmod 600 ~/.config/dotfiles/pi-maintenance-agent.env
$EDITOR ~/.config/dotfiles/pi-maintenance-agent.env
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

Behavior:
- the agent source renders to `~/.local/share/pi-maintenance-agent/`
- the systemd user units render only when `~/.config/dotfiles/pi-maintenance-agent.enabled` exists
- the timer is enabled by `chezmoi apply` only when `~/.config/dotfiles/pi-maintenance-agent.env` exists
- removing the marker file and re-running `chezmoi apply` disables the timer on that machine

Notes:
- `pi-maintenance-agent.env` is machine-local and untracked
- if you want the timer to run while logged out, enable lingering with `loginctl enable-linger "$USER"`

## Script Contract

Setup scripts under `.chezmoiscripts/` are expected to:

1. Source `~/.local/lib/chezmoi-helpers.sh` (directly or via the shared loader).
2. Stay idempotent across repeated `chezmoi apply` runs.
3. Stay quiet by default (`vecho` for verbose detail, `eecho` for essential output).
4. Use state markers under `~/.cache/chezmoi-state`.
5. Gate remote installers/downloads behind `TRUST_ON_FIRST_USE_INSTALLERS=1`.

See `docs/architecture-and-performance.md` for implementation details.

## Advanced Docs

- `ARCHITECTURE.md`
- `plans/README.md`
- `docs/bootstrap-and-flags.md`
- `docs/architecture-and-performance.md`
- `docs/tooling-and-skills.md`
- `docs/secrets-management.md`
