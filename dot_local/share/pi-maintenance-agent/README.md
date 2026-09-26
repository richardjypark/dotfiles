# Pi Maintenance Agent (retired)

This agent is retired. It ran once per day, applied the chezmoi maintenance
flow, and pushed `master` directly. Only one automatic writer may exist, so
routine dependency proposals now use the report-only
`.github/workflows/safe-daily-updates.yml` workflow. Do not opt in new hosts.

`chezmoi apply` stops and disables `pi-maintenance-agent.timer` and
`pi-maintenance-agent.service` on Linux hosts with user systemd, even when the
old marker and runtime files remain. The managed units are inert: the service
runs `/usr/bin/false`, the timer has no calendar event, and neither unit accepts
a manual start. `tests/e2e.sh` checks these properties offline.

## Layout

- `bin/run-maintenance.sh` - retired entrypoint; no managed unit starts it
- `bin/git-ssh.sh` - former isolated SSH command for the agent's pushes
- `config/runtime.env.example` - former machine-local runtime config example
- `prompts/publish.md` - former commit-message instructions for `pi`
- `prompts/repair.md` - former repair instructions for `pi`
- `package.json` / `package-lock.json` - pinned `pi` dependency manifest and committed lockfile
- `tests/e2e.sh` - offline check that the retired units stay inert

## Runtime Notes

- Project path: `~/.local/share/pi-maintenance-agent` (renders only on Omarchy hosts with the marker)
- Local machine opt-in marker: `~/.config/dotfiles/pi-maintenance-agent.enabled`
- Local runtime config: `~/.config/dotfiles/pi-maintenance-agent.env`

Apply leaves the marker and runtime config in place. Remove them manually when
the host no longer needs them.

## Managed npm Pins

Setup no longer installs this package. `chezmoi-bump pi` still regenerates this
committed lockfile together with the Pi CLI lockfile, so both pins stay equal.
