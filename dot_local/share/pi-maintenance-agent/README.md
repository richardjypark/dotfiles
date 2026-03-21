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
- `package.json` - pinned `pi` dependency manifest

## Runtime Notes

- Source repo: `~/.local/share/chezmoi`
- Project path: `~/.local/share/pi-maintenance-agent`
- State/logs: `~/.local/state/pi-maintenance-agent`
- Session data: `~/.local/state/pi-maintenance-agent/sessions`
- Local machine opt-in marker: `~/.config/dotfiles/pi-maintenance-agent.enabled`
- Local runtime config: `~/.config/dotfiles/pi-maintenance-agent.env`
