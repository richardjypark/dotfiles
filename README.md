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
| `czvc` | Runs `chezmoi-check-versions`. | Check pinned versions against upstream releases. |

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

## Optional Private Bootstrap Inputs

Create a local untracked env file for machine-specific values:

```bash
mkdir -p ~/.config/dotfiles
cp ~/.local/share/chezmoi/scripts/bootstrap-private-env.example ~/.config/dotfiles/bootstrap-private.env
chmod 600 ~/.config/dotfiles/bootstrap-private.env
$EDITOR ~/.config/dotfiles/bootstrap-private.env
```

## Script Contract

Setup scripts under `.chezmoiscripts/` are expected to:

1. Source `~/.local/lib/chezmoi-helpers.sh` (directly or via the shared loader).
2. Stay idempotent across repeated `chezmoi apply` runs.
3. Stay quiet by default (`vecho` for verbose detail, `eecho` for essential output).
4. Use state markers under `~/.cache/chezmoi-state`.
5. Gate remote installers/downloads behind `TRUST_ON_FIRST_USE_INSTALLERS=1`.

See `docs/architecture-and-performance.md` for implementation details.

## Advanced Docs

- `docs/bootstrap-and-flags.md`
- `docs/architecture-and-performance.md`
- `docs/tooling-and-skills.md`
- `docs/secrets-management.md`
