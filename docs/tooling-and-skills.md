# Tooling And Skills

## Agent Operating Stack

- `AGENTS.md` — short control-plane rules for agents: safety, work sizing, skill routing, and validation.
- `ARCHITECTURE.md` — stable mental model of repo subsystems, invariants, and change routing.
- `plans/README.md` — canonical Codex planning workflow, including local research/plan artifacts, annotation, approval, and progress tracking.
- `README.md` and `docs/` — user-facing workflows and subsystem-specific deep dives.

## Codex Planning Workflow

Codex is the canonical planning workflow owner for this repo's high-impact work. The expected loop is:

1. Deep-read the relevant subsystem.
2. Write a local `*-research.md` artifact.
3. Write a local `*-plan.md` artifact.
4. Review and annotate the plan in the editor.
5. Revise until the plan is approved.
6. Implement against that approved plan and keep the plan status current.

Claude support remains compatible, but shared planning conventions should point back to the same `plans/README.md` contract instead of duplicating a separate Claude-first process.

## Local Update Commands

- `czu`: resolves a validated selected source, repairs/fetches repo-local `trunk()` via `jj-sync-trunk`, rebases the current change, and applies that same source.
- `czuf`: forced selected-source update with externals/tool refresh; it does not run broad package-manager upgrades or bump source pins.
- `czl`: Omarchy/Arch maintenance wrapper with compatible no-argument full maintenance plus `--system-only`, `--plan`, and `--verbose`. Full mode requires a clean current JJ change, atomically bumps pins, and always runs the Arch convergence apply.
- On macOS, uv setup is Homebrew-first during apply/refresh; pinned GitHub artifact install remains fallback when Homebrew is unavailable.
- `czm`: macOS maintenance wrapper with compatible no-argument full maintenance plus `--system-only`, `--plan`, and `--verbose`. Full mode requires a clean current JJ change, preserves greedy-cask upgrades, atomically bumps pins, uses JJ diff output for conditional final apply, and treats final Homebrew cleanup as warning-only housekeeping.
- `czclean`: managed `~/.local/bin/czclean` manual storage cleanup helper. It defaults to dry-run, runs conservative package-manager/temp cleanup with `--yes`, and keeps Claude history, Docker cleanup, Docker volumes, chezmoi download cache deletion, and aggressive pruning behind explicit flags.
- `czvc`: managed `~/.local/bin/czvc` command that checks pinned versions and exits non-zero when API/network errors make the check incomplete.
- `czb`: managed `~/.local/bin/czb` command that bumps pinned versions with preflight/apply/verify transaction checks and rollback on failure. Multi-dependency `--all` runs add a private portable lock plus invocation-level rollback across generic and Pi targets. `chezmoi-bump pi` resolves to the newest `@earendil-works/pi-coding-agent` version that already satisfies `CHEZMOI_NPM_MIN_VERSION_AGE_DAYS`.
- `chezmoi-health-check`: managed `~/.local/bin/chezmoi-health-check` command that audits key tools, config files, bootstrap security defaults, and agent configuration safety/routing checks.
- `dotfiles-secret-scan`: managed `~/.local/bin/dotfiles-secret-scan` command that runs redacted gitleaks scans over full Git history, the current worktree, or staged Git changes for hook usage. It installs the pinned gitleaks version into the user cache when gitleaks is missing and Go is available.
- `chezmoi-rerun-script`: managed `~/.local/bin/chezmoi-rerun-script` command that clears remembered `run_onchange_*` state for a given source script so the next apply reruns it.
- `pi-agent-run`: managed `~/.local/bin/pi-agent-run` command that executes a Pi markdown agent file non-interactively with its declared model and tools. Use `--model MODEL` or `PI_AGENT_RUN_MODEL=MODEL` to override the declared model; use `default`/`settings` to fall back to Pi's configured default model. Use it when another CLI can run shell commands but does not support Pi's native subagent extension model.
- `jj-fast-agent`: managed `~/.local/bin/jj-fast-agent` wrapper around the shared `~/.pi/agent/agents/jj.md` agent. It defaults to `openai-codex/gpt-5.3-codex-spark:minimal`, but can be run with `--model MODEL` or overridden with `JJ_FAST_AGENT_MODEL`, `PI_JJ_AGENT_MODEL`, or `JJ_AGENT_MODEL`; use `--model default` to use Pi's configured default model. This is the tool-agnostic fallback path for the `jj` skill outside Pi.
- `jj-sync-trunk`: managed `~/.local/bin/jj-sync-trunk` helper, also exposed as `jj trunk-sync`, that detects the current repo's remote default branch and writes a repo-local `trunk()` override when jj's built-in/common trunk resolution is missing or not durable. This keeps dev/main/master projects scalable without hardcoding a global branch in chezmoi jj config.
- `dot_pi/agent/extensions/jj-fast-command.ts` overrides `/skill:jj` (and adds `/jj`) inside Pi so explicit jj requests go straight to the fast helper instead of paying an extra routing LLM turn. The slash commands accept `/jj --model MODEL <task>` and `/skill:jj --model MODEL <task>` for subscription/model compatibility.
- Nested Pi helpers still need outbound provider network access from the invoking shell. Fully sandboxed Codex runs can block that path; if so, use a Codex shell mode that permits network access or run the helper directly outside the sandbox.
- `czu`/`czuf` delegate authoritative remote-head detection and durable `trunk()` repair to `jj-sync-trunk`, then rebase onto `trunk()`; they no longer parse `[git].defaultBranch` or assume `master`.
- Shell previews (`fzf`/`jj-fzf`) resolve `DOTFILES_BAT_CMD` to `bat` first, then `batcat` for Debian/Ubuntu compatibility.
- `private_dot_config/shell/bat.sh` sets conservative defaults when bat is available (`BAT_PAGER=less -RFK`, `BAT_STYLE=numbers,changes`).
- `private_dot_config/shell/alias.sh` resolves `DOTFILES_EZA_CMD` to `eza` first, then `exa`, and remaps `ls`/`ll`/`la`/`lt` in interactive shells.
- `private_dot_config/shell/alias.sh` remaps interactive `diff` to `delta` when installed (`DOTFILES_DELTA_CMD`).
- `private_dot_config/shell/jj-fzf.sh` prefers `delta` for interactive jj diffs, then falls back to bat/plain output.
- `dot_gitconfig.tmpl` configures Git pager and interactive diff filter to prefer `delta` with automatic fallback to `less`/`cat`.

Command definitions live under:

- `dot_local/bin/`
- `private_dot_config/shell/chezmoi.sh`
- `private_dot_config/shell/alias.sh`

## Agent Skills In This Repo

Skills are shared from one repo-managed tree so Pi, Hermes Agent, Codex CLI, Claude Code, and other Agent Skills-compatible clients can follow the same conventions. Codex is the canonical planning path, but the skill folders themselves should follow a tool-agnostic structure:

```text
my-skill/
├── SKILL.md          # required: YAML frontmatter + markdown instructions
├── scripts/          # optional: executable helpers
├── references/       # optional: load-on-demand docs
└── assets/           # optional: templates/resources used in outputs
```

Repo-specific extensions can live alongside that portable layout when needed. In this repo, Codex UI metadata uses an optional `agents/openai.yaml` inside the shared skill folder, but that file is not part of the generic Agent Skills format.

Use the progressive-disclosure model:

1. Discovery: the agent sees only the skill `name` and `description`.
2. Activation: the agent loads the `SKILL.md` body when the task matches.
3. Execution: the agent loads `references/` files or runs bundled scripts only when needed.

Keep `SKILL.md` focused on trigger guidance, workflow, and references to deeper material. Put detailed examples, matrices, and command reference material in `references/` instead of expanding the core instructions indefinitely.

### Shared Skill Tree (`~/.agents/skills/`)

The canonical source tree lives in `private_dot_agents/private_skills/` and renders to `~/.agents/skills/`. Each skill folder follows the Agent Skills pattern directly, including optional metadata only where needed.

Installed client paths are routed to the shared tree:

- Pi discovers `~/.agents/skills` directly.
- `~/.codex/skills` → symlink to `~/.agents/skills`.
- `~/.claude/skills` → symlink to `~/.agents/skills`.
- Hermes Agent opt-in installs keep `~/.agents/skills` in `skills.external_dirs`, preserving local `~/.hermes/skills` precedence.
- `~/.codex/AGENTS.md` → rendered include of the repo-root `AGENTS.md` so Codex starts from the same control-plane rules.

This repo also tracks a project-local Claude policy file at `.claude/settings.local.json`. Treat it as repo policy, not as a personal escape hatch, keep its permissions narrow and domain-scoped, reserve tracked entries for core workflow primitives, and let one-off convenience/bootstrap commands rely on explicit approval instead of tracked pre-approval.

Shared skills currently include:

- `chezmoi-repo-maintainer` — Cross-cutting repo maintenance for docs, templates, shell/tmux behavior, agent instructions, and multi-subsystem changes.
- `jj` — Jujutsu version control workflows, bookmark-safe publishing, recovery, and repo interactive helpers with detailed reference material in `references/jj-reference.md`.
- `jj-remote-truth-reset` — Reset bad local jj history to a repo-specific remote source-of-truth branch, detect default branches without hardcoding `main`/`master`/`dev`, and repair `trunk()` with repo-local overrides.
- `chezmoi-script-maintainer` — Create and maintain `.chezmoiscripts/*` setup scripts with `references/script-patterns.md`.
- `chezmoi-bootstrap-operator` — Bootstrap workflow operations across Omarchy and VPS paths with `references/bootstrap-matrix.md`.
- `dotfiles-version-refresh` — Update pinned tool versions and external dependencies with `references/version-map.md`.
- `brave-tor-policy-hardening` — Maintain the non-optional macOS Brave Browser `TorDisabled=true` managed policy and drift checks.
- `karpathy-guidelines` — Behavioral coding guidelines for surfacing assumptions, avoiding overcomplication, keeping edits surgical, and defining verifiable success criteria.
- `secret-leak-audit` — Redacted secret/PAT/private-key and PII audit workflow for this repo, including the managed `dotfiles-secret-scan` helper, GitHub secret-scanning checks, and incident response steps.
- `grill-me` — Relentless one-question-at-a-time plan/design stress testing with recommended answers for each decision point.
- `deli-auto-research` — Hermes-native protocol for unattended, long-horizon research or engineering projects using durable Kanban state, bounded worker cards, independent verification, stall-aware pivots, and watchdog/recovery layers.

Optional tool metadata lives alongside the shared skill when needed. For example, Codex UI metadata remains in `agents/openai.yaml` inside the canonical skill folder rather than in a separate client-specific copy.

### Shared Sources Of Truth

Skills should have one source of truth: the shared `private_dot_agents/private_skills/` tree. Client-specific paths should be routing only, not separate copies of skill content.

Keep tracked client config conservative as well: dangerous-mode / permission-prompt bypasses and similar safety relaxations belong in client-supported local or per-run overrides, not repo defaults. For example, prefer `codex -c 'projects."/path/to/repo".trust_level="untrusted"'` or `claude --settings /path/to/settings.json --setting-sources user,project,local` over changing tracked repo config.

For cross-cutting work, the canonical references can still live in repo-root docs instead of skill-local copies:

- `ARCHITECTURE.md`
- `plans/README.md`
- `AGENTS.md`

## Future Machine Combination Pattern

Use this pattern for maintainability:

1. Add role/profile behavior first (template/script conditions).
2. Keep shared helper logic in `dot_local/private_lib/chezmoi-helpers.sh`.
3. Keep machine-specific exceptions minimal and documented.
4. Prefer adding pinned version data in `.chezmoidata.toml` and `.chezmoiversion.toml` over ad hoc script constants.
