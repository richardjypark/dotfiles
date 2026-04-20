# Pi CLI Managed Install

Machine-local managed `pi` CLI install used by chezmoi.

The apply-time setup script installs this project with:

- committed `package-lock.json`
- `npm ci`
- `--ignore-scripts`
- exact pinned dependency versions
- reinstall-on-state/lockfile drift, even when the top-level `pi` version is unchanged
- optional `CHEZMOI_NPM_REGISTRY` support for an internal npm proxy
- a default 3-day npm publish-age delay via `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS`, enforced across every versioned package in the committed lockfile
- a pinned `pi-autoresearch` git source instead of mutable repo HEAD

The resulting binary is linked to:

```bash
~/.local/bin/pi
```

## Local Pi Agent Settings Override

This repo tracks a default `~/.pi/agent/settings.json` with
`defaultModel = "gpt-5.4"` and `defaultThinkingLevel = "xhigh"`.

To override Pi settings just for this machine (without committing anything), create:

```bash
~/.config/dotfiles/pi/settings.local.json
```

and optionally:

```bash
~/.config/dotfiles/pi/keybindings.local.json
```

If present, these files completely replace `~/.pi/agent/settings.json` and
`~/.pi/agent/keybindings.json` on apply.

Example workflow for this repo:

```bash
cp ~/.pi/agent/settings.json ~/.config/dotfiles/pi/settings.local.json
# edit the local copy (for example defaultModel)
jq '.defaultModel = "gpt-5.3-codex-spark"' \
  ~/.config/dotfiles/pi/settings.local.json \
  > ~/.config/dotfiles/pi/settings.local.json.tmp && \
  mv ~/.config/dotfiles/pi/settings.local.json.tmp ~/.config/dotfiles/pi/settings.local.json
chezmoi apply
```

Your local overrides are only read from this file path and are not tracked by git.
