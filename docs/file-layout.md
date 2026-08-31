# Chezmoi Source and Target Layout

This repository uses its root as the chezmoi source directory. It does not use
`.chezmoiroot`.

The map below was checked with chezmoi 2.72.1 by using:

```bash
chezmoi source-path
chezmoi managed
chezmoi target-path <source-path>
```

`.chezmoiignore` is the final authority for current host and profile exclusions.
A path can have a valid target path and still be ignored.

## Name Translation

Chezmoi encodes target properties in source names:

- `dot_foo` becomes `.foo`.
- `private_foo` becomes `foo` with private owner-only permissions.
- `executable_foo` becomes executable `foo`.
- A final `.tmpl` suffix is removed after chezmoi renders the Go template.
- Files named `run_before_*`, `run_after_*`, or `run_onchange_*` under
  `.chezmoiscripts/` are apply-time scripts. Chezmoi removes the run prefix from
  their target name and schedules them according to the prefix.

See the official [chezmoi special-files reference](https://www.chezmoi.io/reference/special-files/)
for the complete naming and execution rules.

## Representative Source-to-Target Map

| Source path | Target or role | Current classification |
| --- | --- | --- |
| `AGENTS.md` | `~/AGENTS.md` | Managed agent context |
| `CLAUDE.md` | `~/CLAUDE.md` | Managed client context |
| `ARCHITECTURE.md` | `~/ARCHITECTURE.md` | Managed architecture context |
| `docs/architecture-and-performance.md` | `~/docs/architecture-and-performance.md` | Managed documentation |
| `docs/file-layout.md` | `~/docs/file-layout.md` | Managed documentation |
| `plans/README.md` | `~/plans/README.md` | Managed planning guide |
| `dot_zshrc.tmpl` | `~/.zshrc` | Managed rendered shell config |
| `dot_tmux.conf` | `~/.tmux.conf` | Managed tmux config |
| `private_dot_config/shell/alias.sh` | `~/.config/shell/alias.sh` | Managed private shell config |
| `dot_local/bin/executable_czu` | `~/.local/bin/czu` | Managed executable |
| `dot_local/private_lib/chezmoi-helpers.sh` | `~/.local/lib/chezmoi-helpers.sh` | Managed shared script library |
| `.chezmoiscripts/run_after_39-setup-hermes-agent.sh.tmpl` | `~/.chezmoiscripts/39-setup-hermes-agent.sh` | Managed apply-time script |
| `private_dot_agents/private_skills/chezmoi-repo-maintainer/SKILL.md` | `~/.agents/skills/chezmoi-repo-maintainer/SKILL.md` | Canonical managed shared skill |
| `private_dot_codex/AGENTS.md.tmpl` | `~/.codex/AGENTS.md` | Managed Codex context |
| `private_dot_claude/settings.json` | `~/.claude/settings.json` | Managed Claude configuration |
| `scripts/bootstrap-omarchy.sh` | `~/scripts/bootstrap-omarchy.sh` | Managed bootstrap entry point |
| `bootstrap-vps.sh` | `~/bootstrap-vps.sh` | Managed bootstrap entry point |
| `dot_local/share/pi-cli/package.json` | `~/.local/share/pi-cli/package.json` | Managed embedded application |
| `dot_local/share/pi-maintenance-agent/` | `~/.local/share/pi-maintenance-agent/` | Conditional embedded application |
| `dot_local/share/openrouter-agent/` | `~/.local/share/openrouter-agent/` | Conditional embedded application |

The Pi maintenance agent is enabled only on a supported Omarchy host with its
machine-local marker. The OpenRouter agent is enabled only with its machine-local
marker. Their generated dependency trees are never managed. The Pi maintenance
test is managed with its package because the managed `npm test` command invokes it.

## Repository-Only Paths

These paths remain in the source repository and do not render into `$HOME`:

| Source path | Exclusion source |
| --- | --- |
| `README.md` | `README*` in `.chezmoiignore` |
| `.github/` | Repo-only CI rule in `.chezmoiignore` |
| `.githooks/` and `.gitleaksignore` | Repo-only guardrail rules |
| `tests/` | Repo-only test rule |
| `evals/` and `scripts/eval-skill-routing.py` | Skill-evaluation rules |
| `docs/skill-routing-eval.md` | Skill-evaluation rule |
| Dated `plans/*.md` | `plans/[0-9]*.md` rule |
| `.claude/settings.local.json` | Client-local repository configuration |
| Generated `node_modules/`, build output, and Python bytecode | Generated-file rules |

`plans/README.md` is an exception to the dated-plan rule and is managed. The
scratch research and plan files are repository-only.

`.chezmoiversion.toml` is currently a repository control file, not a managed
home target. Some repository readers still use it. Its separate migration is a
high-risk version-source task; do not delete it as part of layout cleanup.

## Top-Level Ownership

### Chezmoi control data

- `.chezmoidata.toml`: canonical template data and most tool pins.
- `.chezmoiexternal.toml.tmpl`: external target definitions.
- `.chezmoiignore`: host/profile inclusion and repository-only exclusions.
- `.chezmoiremove`: explicit target removals.
- `.chezmoiversion.toml`: legacy repository version manifest until its planned
  reader/writer migration is complete.

### Managed home source

- `dot_*`, `private_dot_*`, and `private_dot_config/`: normal home configuration.
- `dot_local/bin/` and `dot_local/private_lib/`: managed commands and libraries.
- `docs/`, root agent documents, and `plans/README.md`: managed user and agent
  context, except for the exclusions listed above.

### Apply and bootstrap orchestration

- `.chezmoiscripts/`: apply-time installation and convergence.
- `scripts/` and `bootstrap-vps.sh`: first-run and maintenance entry points.
- `dot_local/private_lib/chezmoi-helpers.sh`: shared apply-script contract.

### Agent operating system

- `AGENTS.md`: canonical shared agent policy.
- `ARCHITECTURE.md`: subsystem and change-routing boundaries.
- `plans/README.md`: planning workflow.
- `private_dot_agents/private_skills/`: canonical shared skill source.
- `private_dot_codex/` and `private_dot_claude/`: client-specific rendering and
  configuration.

### Embedded applications

- `dot_local/share/pi-cli/`: managed Pi CLI package wrapper.
- `dot_local/share/pi-maintenance-agent/`: marker- and profile-gated maintenance
  application.
- `dot_local/share/openrouter-agent/`: marker-gated paid-reserve application.

Each embedded application keeps its own package manifest and lockfile. Generated
dependencies and builds are not source files.

## Canonical Change Rules

1. Edit this source repository, not a rendered target in `$HOME`.
2. Use `.chezmoidata.toml` for shared template values and current canonical pins.
3. Use `private_dot_agents/private_skills/` for shared skill changes.
4. Use `AGENTS.md` for common agent policy and `ARCHITECTURE.md` for system facts.
5. Use `README.md` for user operations even though it is repository-only.
6. Use `./tests/all` as the final non-mutating validation command.
7. Check `chezmoi target-path` and `chezmoi managed` before changing path
   classification or assuming that a source is rendered.

## Why There Is No `.chezmoiroot`

The root of this repository is deliberately the source directory. The update and
maintenance wrappers validate and pass one workspace/source path through jj and
chezmoi. Adding a nested source root would introduce a second path contract and
more wrapper logic without reducing current maintenance risk.
