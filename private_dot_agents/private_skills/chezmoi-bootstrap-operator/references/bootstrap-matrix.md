# Bootstrap Matrix

Use this matrix to choose the correct command path.

## Omarchy (Arch-based)

- Workstation:
  - `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation`
- Server:
  - `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server`

Optional flags and env:
- `--repo <chezmoi-repo>`
- `PRIVATE_ENV_FILE=~/.config/dotfiles/bootstrap-private.env`
- `TRUST_ON_FIRST_USE_INSTALLERS=1` only when installer-based setup is intentionally allowed

Role behavior:
- `CHEZMOI_ROLE` is exported from bootstrap (`workstation` or `server`).
- Bootstrap saves that role and `profile=omarchy` in the active local chezmoi config before apply.
- Server role skips some local-dev tooling during `chezmoi apply/update`.

## Debian/Ubuntu VPS (root-run flow)

Baseline command:

```bash
USERNAME=rich DOTFILES_REPO=https://github.com/<owner>/dotfiles.git ./bootstrap-vps.sh
```

Security defaults:
- `ALLOW_PASSWORDLESS_SUDO=0`
- `COPY_ROOT_AUTH_KEYS=0`
- `TRUST_ON_FIRST_USE_INSTALLERS=0`

Phased hardening model:
1. Bootstrap with safe defaults.
2. Confirm access paths (SSH/Tailscale).
3. Run the staged post-bootstrap lockdown from a working Tailscale SSH session.
4. Confirm from a new Tailscale SSH connection within five minutes.

## Post-bootstrap Lockdown

For server role after Tailscale access is verified:

```bash
sudo ~/.local/share/chezmoi/scripts/server-lockdown-tailscale.sh
sudo ~/.local/share/chezmoi/scripts/server-lockdown-tailscale.sh --confirm
```

## Private Inputs (Never Commit)

Keep private values in local, untracked files:
- `~/.config/dotfiles/bootstrap-private.env`
- Typical keys: `BOOTSTRAP_GIT_EMAIL`, `BOOTSTRAP_SSH_PUBLIC_KEY`, `BOOTSTRAP_SSH_PUBLIC_KEY_FILE`, `BOOTSTRAP_HOST_ALIAS`
