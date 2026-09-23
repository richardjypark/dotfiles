# Developer platforms

This repository supports macOS and Omarchy/Arch workstations, plus
Debian/Ubuntu servers. All listed tools have a long-term free use path. Some
tools can offer paid services, but these files do not start a trial.

## Workstation runtimes

Chezmoi installs mise through Homebrew on macOS or pacman on Arch. On a
Debian/Ubuntu development host, it uses the distribution `extrepo` definition
for mise after the existing remote-installer trust flag is set. The server
role skips project runtimes. The global mise config gives managed agents a
Node default. A project's `mise.toml` can select another Node version and
matching Erlang/Elixir versions. Python stays under uv.
The Debian/Ubuntu bootstrap passes `CHEZMOI_ROLE=server` to its apply step.
For later manual server applies, set the same role explicitly.

Use `mise install` and `mise exec -- <command>` in scripts. The interactive
zsh shell activates mise, and non-interactive zsh uses shims. The repo does
not delete an existing `~/.nvm` directory. During apply, it removes only old
NVM symlinks that this repo created in `~/.local/bin`. Check any custom NVM
setup before applying on a workstation.

Omarchy keeps its own shell startup files. Use `mise exec -- <command>` there
without changing them, or add the [mise activation line](https://mise.jdx.dev/dev-tools/shims.html)
to your machine-local interactive shell config after review.

For a mixed-language project, start with
[`examples/mixed-monorepo`](../examples/mixed-monorepo/README.md). Choose
runtime versions that its Phoenix release supports. Commit project lockfiles
in that project, not in these dotfiles.

## Package sets

The package files are reviewable sets, not automatic removal policies:

- macOS: `brew bundle --no-upgrade --file=packages/macos-workstation.Brewfile`
- Omarchy/Arch: `packages/arch-workstation.txt` lists official packages;
  `scripts/bootstrap-omarchy.sh` remains the first-run installer.
- Debian/Ubuntu server: `packages/debian-server.yml` supplies the Ansible role.

Keep existing bootstrap and security scripts for SSH, firewall, Tailscale,
and first login. The Ansible role only converges common packages after those
checks. It has no tracked inventory. Use a private inventory and first run
`ansible-playbook -i <private-inventory> ansible/server.yml --check` from a
workstation with access to the server.

## Containers on macOS

Colima is a free local Docker-compatible runtime. The Brewfile can install
it and the Docker CLI. Installation does not start a VM or change the Docker
context. On a Mac where OrbStack is in use, first inspect active services,
images, and volumes. Only then run `colima start` and select its Docker
context for a specific session or project. Do not delete OrbStack data until
the applications and volumes have been migrated and verified.

## Validation

`./tests/all` runs ShellCheck on rendered Bash templates and Bash scripts at
error severity, and actionlint on GitHub workflows. Local runs report a skip
when a lint tool is absent. CI sets `REQUIRE_LINT_TOOLS=1`, so a missing tool
fails validation. ShellCheck warning-level cleanup is separate from this
first gate because existing scripts have warning debt.
