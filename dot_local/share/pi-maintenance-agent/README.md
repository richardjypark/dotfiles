# Pi Maintenance Agent

Machine-local scheduled maintenance agent for opted-in hosts.

It runs once per day at `5:01 PM America/New_York`, executes the non-sudo parts of the existing chezmoi maintenance flow, and uses `pi` to:

- inspect and summarize conflicts
- attempt one automated conflict repair
- generate a descriptive jj commit message from the actual diff
- let the wrapper move the `master` bookmark to `@`
- let the wrapper push `master`
- let the wrapper create the next working copy with `jj new master`

## Layout

- `bin/run-maintenance.sh` - main scheduled entrypoint
- `config/runtime.env.example` - machine-local runtime config example
- `prompts/publish.md` - read-only commit-message instructions for `pi`
- `prompts/repair.md` - one-shot repair instructions for `pi`
- `package.json` / `package-lock.json` - pinned `pi` dependency manifest + committed lockfile

## Runtime Notes

- Source repo: `~/.local/share/chezmoi`
- Project path: `~/.local/share/pi-maintenance-agent`
- State/logs: `~/.local/state/pi-maintenance-agent`
- Session data: `~/.local/state/pi-maintenance-agent/sessions`
- Local machine opt-in marker: `~/.config/dotfiles/pi-maintenance-agent.enabled`
- Local runtime config: `~/.config/dotfiles/pi-maintenance-agent.env`

## Managed npm Safety

The managed Pi dependency is installed with:

- committed `package-lock.json`
- `npm ci`
- `--ignore-scripts`
- exact pinned versions
- reinstall-on-state/lockfile drift, even when the top-level `pi` version is unchanged
- an optional internal npm registry/proxy via `CHEZMOI_NPM_REGISTRY`
- a default 3-day npm publish-age delay via `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS`, enforced across every versioned package in the committed lockfile

The scheduled maintenance flow also defaults to a freeze policy for npm-backed version bumps:

- `chezmoi-bump` runs only the non-npm dependency set by default
- npm-backed bumps such as Claude Code are excluded from unattended daily runs
- set `PI_MAINTENANCE_ALLOW_NPM_BUMPS=1` in the machine-local runtime env only if you intentionally want the agent to include npm-backed bumps
