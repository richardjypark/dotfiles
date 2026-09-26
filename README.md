# github.com/richardjypark/dotfiles

Dotfiles managed with [chezmoi](https://github.com/twpayne/chezmoi).

## Fresh Machine Install

### Omarchy / Arch (personal machine or server)

```bash
sudo pacman -S --noconfirm --needed chezmoi git curl
chezmoi init richardjypark
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

Run that command from a working Tailscale SSH session as the non-root operator.
Keep it open, start a new Tailscale SSH session, and confirm within five minutes:

```bash
sudo ~/.local/share/chezmoi/scripts/server-lockdown-tailscale.sh --confirm
```

The local timer restores the prior SSH and UFW configuration if confirmation
does not arrive. For the personal-cloud nftables path, first run
`scripts/setup-personal-cloud-tailscale.sh`, set the tailnet SSH policy, and
verify a new Tailscale SSH session. Run it with `--lockdown` from that session,
then run it with `--confirm` from another new session within five minutes.
Keep the first session open and do not restart the server before confirmation.
The rollback timer and its saved files are in `/run` and do not survive a restart.

### Debian / Ubuntu VPS

Clone and run as root on a fresh VPS. Set `USERNAME` to the intended non-root
administrator and install a public key for that user before this command, or
use `COPY_ROOT_AUTH_KEYS=1` when root already has a usable authorized key.

```bash
git clone https://github.com/richardjypark/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
USERNAME=rich DOTFILES_REPO="https://github.com/richardjypark/dotfiles.git" TRUST_ON_FIRST_USE_INSTALLERS=1 bash ./bootstrap-vps.sh
```

### macOS (workstation)

```bash
brew install chezmoi git curl
chezmoi init --apply richardjypark
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

Bootstrap saves `role=server` and `profile=standard` in the active local
chezmoi config before the first apply. Omarchy bootstrap saves the selected
role and `profile=omarchy`. Later plain applies use those saved values.
Nonempty `CHEZMOI_ROLE` and `CHEZMOI_PROFILE` values override them for one run;
`standard` explicitly keeps the regular shell targets on a host with Omarchy.

Workstation project runtimes use mise for Node and Elixir/Erlang; uv still owns
Python. See [developer platforms](docs/developer-platforms.md) for the
mixed-monorepo example, package sets, lint checks, and the optional free
Colima path. Servers skip project runtime setup by default. A server with an
enabled JavaScript agent installs the pinned Node runtime without the
workstation pnpm and yarn installs.

Interactive shells keep a reachable inherited SSH agent, including forwarded
agents with no loaded keys. macOS uses the session agent when available; Linux
starts one reusable local OpenSSH agent when needed. Set `DOTFILES_SSH_AGENT=gpg`
locally only when your GnuPG agent has SSH support configured. Shell startup
does not create or replace `gpg-agent.conf`.

### macOS Brave Browser Tor Policy

On macOS, `chezmoi apply` enforces a non-optional Brave Browser managed policy:
`com.brave.Browser` `TorDisabled=true`. The repo intentionally has no
role/profile/env opt-out for this control; re-run `chezmoi apply` with sudo
available if `chezmoi-health-check` reports policy drift.

## Update Commands

| Command | What it does | When to use |
| --- | --- | --- |
| `chezmoi update` | Pulls latest dotfiles from upstream and applies them. | Standard sync from repo changes. |
| `czu` | Resolves one validated source workspace, repairs/fetches `trunk()` through `jj-sync-trunk`, rebases the current change onto `trunk()`, then applies that same selected source. Saved local profile data takes priority over Omarchy host detection. | Daily update when you want the jj-based workflow. Set `CHEZMOI_SOURCE_DIR=/absolute/workspace` to select a non-default source workspace. |
| `czuf` | Same selected-source/trunk flow as `czu`, plus `TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1` and `chezmoi apply --refresh-externals --force`. It does not run broad package-manager upgrades or bump source pins. | Full refresh when pinned tools/externals changed or state needs rebuilding. On macOS, use `czm` for one-command app + pin maintenance. |
| `czl [--system-only \| --bump-pins] [--plan] [--verbose]` | Omarchy/Arch maintenance. No arguments preserve the full workflow: clean-source gate, `czuf`, `pacman -Syu`, atomic `chezmoi-bump --all`, and final forced selected-source apply. `--system-only` skips source-pin mutation but keeps the Arch convergence apply. | Daily Arch maintenance. Use `--plan` for a non-installing preview or `--system-only` when the current JJ change is intentionally dirty. |
| `czm [--system-only \| --bump-pins] [--plan] [--verbose]` | macOS maintenance. No arguments preserve the full Homebrew + atomic pin-bump workflow. The final selected-source apply runs only when the clean-source bump leaves a JJ diff; Homebrew cleanup runs last and is warning-only. `--system-only` skips source-pin mutation and the final pin apply. | Daily macOS maintenance. Use `--plan` for a non-installing preview or `--system-only` when the current JJ change is intentionally dirty. |
| `czclean` | Managed wrapper command in `~/.local/bin/czclean`: manual storage cleanup helper. Defaults to dry-run; run `czclean --yes` for conservative cache cleanup, add `--claude`, `--claude-history`, `--docker`, `--docker-volumes`, `--chezmoi-cache`, or `--aggressive` only when you intentionally want those extra cleanup scopes. | Reclaim package-manager, temporary, and opt-in tool cache bloat safely. |
| `czvc` | Managed wrapper command in `~/.local/bin/czvc`: runs `chezmoi-check-versions`, which reports each pinned external as `eligible`, `too_new`, `major_review`, `current`, or `unsupported` under the seven-day stable-release rule, and exits non-zero when API/network errors make results incomplete. | Check pinned versions against upstream releases. |
| `czb` | Runs `chezmoi-bump` with fail-closed transaction checks. `chezmoi-bump --all` snapshots all managed pin/lock targets, serializes source mutation with a portable private lock, and restores the invocation-start state if any later dependency or catchable signal fails. | Bump pinned dependency versions safely. Pi resolves to the newest release satisfying `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS`. |
| `chezmoi-health-check` | Managed helper in `~/.local/bin/chezmoi-health-check`: audits key tool installs, config files, bootstrap security defaults, and agent configuration safety/routing checks. | Run after bootstrap/apply or when debugging local drift. |
| `dotfiles-secret-scan` | Managed helper in `~/.local/bin/dotfiles-secret-scan`: runs redacted gitleaks scans over full Git history, the current worktree, or staged Git changes. It installs the pinned gitleaks version into the user cache when needed and Go is available. | Check for leaked secrets, personal access tokens, private keys, and credential-like values before publishing dotfiles changes. |
| `chezmoi-rerun-script <source-script-path>` | Managed helper in `~/.local/bin/chezmoi-rerun-script`: clears chezmoi's remembered `run_onchange_*` state for the given source script so the next `chezmoi apply` reruns it. | Recover from manual deletions or force a one-off rerun of a bootstrap/setup script after local drift. |
| `pi-agent-run [--model MODEL] <agent-markdown-file> [task...]` | Managed helper in `~/.local/bin/pi-agent-run`: runs a Pi markdown agent file non-interactively with its declared model and tools, or an override from `--model`/`PI_AGENT_RUN_MODEL`; use `--model default` for Pi's configured default model. | Reuse a Pi agent from another shell-driven CLI or script. |
| `jj-fast-agent [--model MODEL] [task...]` | Managed wrapper in `~/.local/bin/jj-fast-agent`: runs the shared `jj` Pi agent, defaulting to `openai-codex/gpt-5.3-codex-spark:minimal` but overridable with `--model`, `JJ_FAST_AGENT_MODEL`, `PI_JJ_AGENT_MODEL`, or `JJ_AGENT_MODEL`; use `--model default` to use Pi's configured default model. | Fast jj/git-only delegation from tools that can run shell commands but do not support Pi subagents directly. |
| `jj-sync-trunk` / `jj trunk-sync` | Managed helper in `~/.local/bin/jj-sync-trunk`: detects the current repo's remote default branch and sets a repo-local `trunk()` override when jj's built-in/common trunk resolution is missing or not durable. | Fix or verify per-repo jj trunk behavior without hardcoding `dev`, `main`, or `master` globally. |

`cz*` commands are installed in `~/.local/bin` and do not rely on shell aliases.
Aliases in `~/.config/shell/alias.sh` are convenience shortcuts only.
Repo-managed `jj fetch` is intentionally quiet (`jj git fetch --quiet`); run raw `jj git fetch` when you want rebase/abandon diagnostics.

Maintenance mode contract:
- No-argument `czl`/`czm` remains full maintenance for compatibility; `--bump-pins` makes that intent explicit.
- Full pin-bump mode requires a clean current JJ working-copy change before sudo, package upgrades, or source mutation. `--system-only` permits a dirty current change because it does not run `chezmoi-bump`.
- `--plan` performs no fetch/rebase/config write, package installation, tracked-source mutation, or home-directory apply. It may perform network reads and cache writes while checking remote trunk, package updates, and upstream pin versions.
- `--verbose` exports `VERBOSE=true` and prints command/synchronization details. Unknown or conflicting mode flags exit with status 2.
- `CHEZMOI_SOURCE_DIR` (or the backward-compatible `CHEZMOI_DIR`) must name an absolute validated JJ workspace root. If unset, wrappers use `chezmoi source-path`; they no longer silently fall back to a conventional directory.

### Sync a jj Repo to Its Remote Default Branch

Use this branch-agnostic one-liner to fetch `origin`, detect its current default
branch (`master`, `main`, `dev`, or another name), and start a clean working-copy
commit from the updated remote trunk:

```bash
jj trunk-sync --remote origin && jj new 'trunk()'
```

`jj trunk-sync` updates the repo-local `trunk()` definition when needed. `jj new`
then leaves any previous local changes safely in their existing jj changes instead
of replaying or discarding them. To intentionally preserve and replay the current
local stack on the updated trunk, use `jj rebase -b @ -d 'trunk()'` instead; that
operation can produce conflicts.

Shell preview behavior:
- `fzf` and `jj-fzf` previews prefer `bat` and auto-fallback to `batcat` on Debian/Ubuntu-style installs.
- If neither command is available, previews degrade to plain output until `bat` is installed.
- `jji`/`jjfi` diff rendering prefers `delta`, with fallback to `bat`/`batcat`, then plain `less` output.
- Interactive shell aliases map `ls`/`ll`/`la`/`lt` to `eza` (or `exa` fallback) when installed.
- Interactive shell aliases map `diff` to `delta` when installed.
- Git pager and interactive patch diff filtering prefer `delta` and fall back to `less`/plain output when missing.

`chezmoi-bump` safety/debug flags:
- `--automatic --all` applies the fixed routine policy: only stable releases published at least seven full days ago, with every required platform asset and checksum, strict verification, rollback, and the public npm registry. It reports major and `0.x` minor updates for review instead of applying them, and lists Claude Code, Tailscale, Codex, and the zsh plugins as manual. Add `--check` for a report without downloads or source writes.
- `--manifest-out <path>` writes the computed transaction manifest (multi-dep runs emit one file per dep).
- `--no-strict` relaxes post-apply verification (strict is default).
- `--no-rollback` keeps single-dependency mutations on failure for debugging. `--all` remains invocation-atomic and restores all managed source targets even when this per-dependency debug flag is set.
- The `--all` source lock lives under `${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-maintenance/chezmoi-bump`; ambiguous stale locks are reported with owner metadata and are never auto-removed.

## Role + Profile Matrix

| Dimension | Value | Effect |
| --- | --- | --- |
| `CHEZMOI_ROLE` | `workstation` | Full personal workstation toolchain. |
| `CHEZMOI_ROLE` | `server` | Server-focused setup, skips workstation-only tooling. |
| `CHEZMOI_PROFILE` | `omarchy` | Manage `.zshenv` and `.zshrc` so Ghostty's zsh starts Herdr with mise tools on `PATH`; keep local Omarchy terminal settings and skip tmux setup. |
| `CHEZMOI_PROFILE` | `standard` | Keep standard managed shell/terminal targets. |

| Optional tool | Server default | Opt-in marker | Runtime |
| --- | --- | --- | --- |
| Pi CLI | Skip | `~/.config/dotfiles/pi-cli.enabled` on a supported Omarchy host | Pinned Node through mise |
| Pi maintenance agent | Skip | `~/.config/dotfiles/pi-maintenance-agent.enabled` on Omarchy | Pinned Node through mise |
| OpenRouter Agent | Skip | `~/.config/dotfiles/openrouter-agent.enabled` | Pinned Node through mise |
| Hermes TUI | Skip | `~/.config/dotfiles/hermes-agent.enabled` | Pinned Node for the local TUI build |

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

Create an untracked local Pi settings override file for this repository if you want to use a different model/provider locally without changing tracked defaults:

```bash
mkdir -p ~/.config/dotfiles/pi
cp ~/.pi/agent/settings.json ~/.config/dotfiles/pi/settings.local.json
# edit model/thinking settings as needed
$EDITOR ~/.config/dotfiles/pi/settings.local.json
```

If `~/.config/dotfiles/pi/settings.local.json` exists, `chezmoi apply` will prefer it over the tracked `~/.pi/agent/settings.json` for this machine.
The local settings file must be a JSON object with the managed
`pi-autoresearch` package pin in its `packages` array. A local keybindings
override must also be a JSON object. The override writer keeps unchanged
files and sets changed target files to mode `0600`.
After you remove a local override, accept chezmoi's prompt to restore the
managed default, or run a scoped `chezmoi apply --force` for that Pi target.

### IBKR data platform local dependencies

Opt in on a single workstation when developing the `data.tildacapital.com` IBKR access-discovery worker:

```bash
mkdir -p ~/.config/dotfiles
touch ~/.config/dotfiles/ibkr-data-platform-deps.enabled
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

When enabled, chezmoi ensures a pinned user-local Go toolchain under `~/.local/share/go/` and checks
for a Java runtime for the IBKR Client Portal Gateway. The marker file is machine-local and
untracked, so other hosts do not install these dependencies by default.

### Hermes Agent local install

Hermes Agent is opt-in per machine for always-on personal hosts/VPSes:

```bash
mkdir -p ~/.config/dotfiles
touch ~/.config/dotfiles/hermes-agent.enabled
# Optional: keep the messaging/cron gateway running under user systemd.
touch ~/.config/dotfiles/hermes-agent-gateway.enabled
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

When enabled, chezmoi installs a pinned Hermes Agent checkout under `~/.local/share/hermes-agent`,
creates `~/.local/bin/hermes`, and uses a lean locked uv environment for messaging/cron/CLI usage
without the heavier browser, voice, RL, or development extras. Hermes runtime data lives in
`~/.hermes/`. API keys and other secret env values are not managed by this repo; run
`hermes setup` or `hermes gateway setup` locally after install. For public-repo safety,
this repo does not track `~/.hermes/config.yaml` or `~/.hermes/.env`. Non-sensitive
Hermes preferences live in `.chezmoidata.toml` under `[hermes.preferences]` and
`[hermes.delegation]`, and the always-run Hermes setup script compares and
applies them in one atomic config update on each
`chezmoi apply`: `model.provider=anthropic`, `model.default=claude-opus-5-5`,
`model.base_url=https://api.anthropic.com`,
`display.show_reasoning=true`, `agent.reasoning_effort=xhigh`,
`agent.service_tier=""` (normal speed), `agent.max_turns=1000`,
`goals.max_turns=1000`, `model.context_length=500000`, and
`tui_by_default=true`. Delegation provider, model, and reasoning overrides are
empty by default, so spawned subagents inherit the active parent route. This
avoids a public, account-specific model pin. A machine that needs a different
delegation route can set a machine-local Hermes override. Existing
Hermes sessions keep their startup delegation config; start a new CLI session or
restart the gateway to pick up delegation changes. The empty main-agent
service tier explicitly keeps normal processing rather than OpenAI Priority
Processing or Anthropic Fast Mode.
The setup also keeps `~/.agents/skills` in Hermes'
`skills.external_dirs`, so shared repo-managed skills such as
`karpathy-guidelines` and `deli-auto-research` are available while local
`~/.hermes/skills` copies still take precedence. Hermes 0.16.0 treats goal budgets as positive integer
caps rather than supporting an unlimited sentinel, so the repo uses a high finite
budget for long `/goal` runs while retaining a runaway-loop guardrail. When
`tui_by_default` is enabled, the managed
`~/.local/bin/hermes` launcher sets `HERMES_TUI=1` for interactive terminals
unless already set, so `hermes` opens the richer TUI status line. That status
line includes the current model reasoning effort (for example `medium`) and the
launch working directory with git branch or the current jj workspace plus nearest
jj bookmark, using a wider right-side budget so roomy terminals show enough of
deep paths to disambiguate similar checkouts. The setup script
also reapplies small local Hermes TUI patches that mute inline diff red/green highlight
backgrounds in both dark and light themes and hide the inactive `voice off`
status-bar segment while still showing active voice/TTS states like `voice on`,
`voice on [tts]`, `● REC`, and `◉ STT`; these work around Hermes' default TUI colors/status
density rather than Ghostty's palette.
It also prebuilds the TUI bundle during `chezmoi apply` and points the managed
launcher at that prebuilt bundle so interactive startup does not spend several
seconds rebuilding the Ink/TUI JavaScript on first launch.

Removing `~/.config/dotfiles/hermes-agent-gateway.enabled` and re-running `chezmoi apply` disables
the gateway user service on that machine. Removing the install marker stops future managed setup but
leaves the local checkout and `~/.hermes/` data in place for manual review/removal.

### Optional OpenRouter paid-credit reserve agent

`openrouter-agent` is a separate, manually invoked TypeScript TUI for times when the normal Codex
allowance is unavailable. It does **not** change Hermes' default `anthropic` route, add an
automatic provider fallback, or spend OpenRouter credits in the background. Installation is
disabled by default and is opt-in per machine:

```bash
install -d -m 700 ~/.config/dotfiles
install -m 600 /dev/null ~/.config/dotfiles/openrouter-agent.enabled
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

The setup uses the committed npm lockfile, enforces the repository's npm publish-age policy,
disables dependency lifecycle scripts, builds under `~/.local/share/openrouter-agent/`, and creates
`~/.local/bin/openrouter-agent`. The real credential is machine-local and must never be added to
chezmoi. Either export `OPENROUTER_API_KEY` only for the process that launches the command, or create
the private runtime file without putting the value in shell history:

```bash
install -d -m 700 ~/.hermes
install -m 600 /dev/null ~/.hermes/.env
$EDITOR ~/.hermes/.env
# Add this inside the editor: OPENROUTER_API_KEY=<your dedicated key>
chmod 600 ~/.hermes/.env

openrouter-agent --doctor  # local validation only; no OpenRouter request
openrouter-agent --demo    # offline UI demo; no key or network request
openrouter-agent           # explicit paid-credit session
```

Both `~/.config/dotfiles/` and `~/.hermes/` must be current-user-owned real directories that are not
writable by group or others. The marker and credential must be current-user-owned regular files,
not symlinks; the credential must be exactly mode `0600`.

Use a dedicated OpenRouter key with an expiry and conservative account spending limit. The managed
defaults stop one agent turn when it reaches 24 steps or USD 0.25 in reported cost, do not
automatically retry ambiguous paid failures, request `data_collection=deny`, require routed
providers to support request parameters, and use `openai/gpt-5.6-luna` over the Responses API.
When Luna is unavailable or undesirable, explicitly select the checked-in Kimi K3 profile for one
process; it uses Chat Completions and permits endpoint fallback only among providers serving that
same model:

```bash
OPENROUTER_AGENT_MODEL=moonshotai/kimi-k3 openrouter-agent
```

Only models in the managed `modelProfiles` map are accepted, and transport cannot be overridden by
the environment. `OPENROUTER_AGENT_MAX_STEPS`, `OPENROUTER_AGENT_MAX_OUTPUT_TOKENS`, and
`OPENROUTER_AGENT_MAX_COST_USD` may lower their checked-in ceilings for a process but cannot raise
them. The output-token ceiling applies to each Kimi Chat request; the cost limit prevents an
additional tool-driven request after reported cumulative cost reaches the limit, but no client-side
limit can guarantee the cost of an already-submitted request. Tool calls that write/edit files or
run shell commands pause for a real yes/no approval. File tools stay inside the directory where the
command was launched and refuse common credential paths. Interactive use also refuses `$HOME`
itself as a workspace; start the command inside a specific project directory. Sessions are private
files under `${XDG_STATE_HOME:-~/.local/state}/openrouter-agent/sessions/`, outside this repository.

To disable the command, remove `~/.config/dotfiles/openrouter-agent.enabled` and run `chezmoi apply`.
To prevent all future OpenRouter use, also remove only the `OPENROUTER_API_KEY` entry from the
machine-local environment/file and revoke the dedicated key in OpenRouter. Do not delete
`~/.hermes/.env` wholesale if it contains unrelated local credentials.

## Pi Maintenance Agent

On macOS and Omarchy hosts, `chezmoi apply` installs the managed local `pi` CLI from a committed lockfile and ensures the `pi-autoresearch` package is present from a pinned git commit for that user profile.
The scheduled `pi-maintenance-agent` is retired. It applied, committed, and pushed `master` directly, and only one automatic writer may exist. Do not opt in new hosts.

- On every Linux host with user systemd, `chezmoi apply` stops and disables `pi-maintenance-agent.timer` and `pi-maintenance-agent.service`, even when the old marker and runtime files remain. Apply fails if a unit stays active or enabled, and it warns when user systemd is unavailable.
- The rendered units are inert: the service runs `/usr/bin/false`, the timer has no calendar event, and neither unit accepts a manual start.
- The retired source and units still render only on Omarchy hosts with `~/.config/dotfiles/pi-maintenance-agent.enabled`. Apply leaves the machine-local marker and `pi-maintenance-agent.env` in place; remove them manually when the host no longer needs them.
- Routine dependency proposals move to `.github/workflows/safe-daily-updates.yml`. It runs only on manual dispatch from the default branch and only reports: `chezmoi-bump --automatic --all --check`. A schedule and a pull-request publisher come later, after every opted-in host is verified and the `master` rules require checks.

Managed npm installs for the Pi CLI use the committed lockfile, `npm ci`, and `--ignore-scripts`. Lockfile or state drift forces a fresh `npm ci` even when the pinned `pi` version is unchanged. `pi-autoresearch` comes from a pinned git commit. Manual runs delay the public npm registry path with `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS=3` and check every versioned package in each committed lockfile; automatic mode fixes the delay at seven days and requires the public registry. `chezmoi-bump pi` regenerates both committed Pi lockfiles against the newest npm version that satisfies the delay.

## Script Contract

Setup scripts under `.chezmoiscripts/` are expected to:

1. Load `chezmoi-helpers.sh` through the shared loader. Before-scripts use the selected source checkout; after-scripts use the deployed copy.
2. Stay idempotent across repeated `chezmoi apply` runs.
3. Stay quiet by default (`vecho` for verbose detail, `eecho` for essential output).
4. Use state markers under `~/.cache/chezmoi-state`.
5. Gate remote installers/downloads behind `TRUST_ON_FIRST_USE_INSTALLERS=1`.

The compatibility helper loads small `core`, `artifacts`, and `npm` modules
from `~/.local/lib/chezmoi/`. A failed quiet command prints its captured error
and keeps its exit status. A state marker is written only after a tool passes
its readiness check. Release installers stage and check a new binary before
they replace the old one. Hermes uses separate install, config, gateway, and
TUI modules. The helper checksum in each `run_onchange` script makes a helper
change trigger that script again. `run_after` scripts run on each apply.

See `docs/architecture-and-performance.md` for implementation details.

## Advanced Docs

- `ARCHITECTURE.md`
- `plans/README.md`
- `docs/file-layout.md`
- `docs/bootstrap-and-flags.md`
- `docs/architecture-and-performance.md`
- `docs/tooling-and-skills.md`
- `docs/skill-routing-eval.md` — repo-only guide to the skill-selection smoke eval; excluded from chezmoi rendering.
- `docs/secrets-management.md`
