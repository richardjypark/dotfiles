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
