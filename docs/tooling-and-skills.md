# Tooling And Skills

## Agent Operating Stack

- `AGENTS.md` — short control-plane rules for agents: context, safety, publishing, planning triggers, validation, and enforced checks.
- `ARCHITECTURE.md` — stable mental model of repo subsystems, invariants, and change routing.
- `plans/README.md` — canonical planning workflow, including local research/plan artifacts, annotation, and progress tracking.
- `README.md` and `docs/` — user-facing workflows and subsystem-specific deep dives.

## Planning Workflow

`AGENTS.md` says when to plan, and `plans/README.md` owns the workflow for every agent (Claude Code, Codex, Pi, Hermes Agent).

## Local Update Commands

Project runtimes, package sets, and the optional Colima path are described in
`docs/developer-platforms.md`. mise selects Node and Elixir/Erlang per project;
uv remains the Python owner.

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
- `dotfiles-push`: managed publisher for one explicit JJ bookmark. It checks private source paths, outgoing commit emails, and secrets before pushing. Each clone can use it through a repo-local `jj push` alias; see `docs/secrets-management.md`.
- `chezmoi-rerun-script`: managed `~/.local/bin/chezmoi-rerun-script` command that clears remembered `run_onchange_*` state for a given source script so the next apply reruns it.
- `pi-agent-run`: managed `~/.local/bin/pi-agent-run` command that executes a Pi markdown agent file non-interactively with its declared model and tools. Use `--model MODEL` or `PI_AGENT_RUN_MODEL=MODEL` to override the declared model; use `default`/`settings` to fall back to Pi's configured default model. Use it when another CLI can run shell commands but does not support Pi's native subagent extension model.
- `jj-fast-agent`: managed `~/.local/bin/jj-fast-agent` wrapper around the shared `~/.pi/agent/agents/jj.md` agent. It defaults to `anthropic/claude-haiku-5-5:minimal`, but can be run with `--model MODEL` or overridden with `JJ_FAST_AGENT_MODEL`, `PI_JJ_AGENT_MODEL`, or `JJ_AGENT_MODEL`; use `--model default` to use Pi's configured default model. This is the tool-agnostic fallback path for the `jj` skill outside Pi.
- The jj agent's Haiku route is separate from Hermes delegation. Use `jj-fast-agent --model default` or a machine-local Pi model override to run it on another model.
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

Skills are shared from one repo-managed tree so Pi, Hermes Agent, Codex CLI, Claude Code, and other Agent Skills-compatible clients can follow the same conventions. Claude Code is the canonical planning path, but the skill folders themselves should follow a tool-agnostic structure:

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
- No client gets a global copy of `AGENTS.md`. Each client reads it from the repo root, so it applies only in this repo. `run_onchange_after_95-remove-home-agent-guides.sh` removes the old `~/AGENTS.md`, `~/CLAUDE.md`, and `~/.codex/AGENTS.md` copies.

This repo also tracks a project-local Claude policy file at `.claude/settings.local.json`. Treat it as repo policy, not as a personal escape hatch, keep its permissions narrow and domain-scoped, reserve tracked entries for core workflow primitives, and let one-off convenience/bootstrap commands rely on explicit approval instead of tracked pre-approval.

The same file holds the rules that must not depend on the model. Deny and ask rules win over the broad `Bash(git:*)`, `Bash(jj:*)`, and `Bash(chezmoi:*)` allows (deny, then ask, then allow), and Read deny rules also go to the sandbox, so a test script or dependency cannot read those files either. That holds only for anchored patterns (`**/*.env`, `~/.ssh/id_*`, `//abs/path`, `/project/path`): a bare pattern such as `*.env` binds the Read tool but not the sandbox, and the sandbox ignores `!` exceptions, so it also blocks `.env.example`. `test_read_deny_rules_use_forms_the_sandbox_enforces` checks the form. The PreToolUse hook `.claude/hooks/backup-before-risky.py` bundles the repo to `~/.local/state/dotfiles-backups/` (newest 10 kept, owner-only permissions) before `./tests/all`, `chezmoi apply|update|init` (not with `--dry-run`), and setup scripts. The `chezmoi apply *` ask rule still prompts for a dry run, because no allow rule can override an ask rule. It records uncommitted and untracked files under `refs/dotfiles-backup/working-tree`, and exits 2 to block the command if the bundle fails. To restore it, run `git fetch <bundle> refs/dotfiles-backup/working-tree` in a new repo, then `git checkout FETCH_HEAD`; `git clone` does not copy that ref.

Hooks run outside the sandbox, so a hook may run only files that sandboxed commands cannot change: `.claude/hooks/` and git with its `.git/config`. The sandbox can write `.githooks/`, which this clone's `core.hooksPath` names, so the backup hook runs every git call with `core.hooksPath=/dev/null` and `core.fsmonitor=false`. That rules out a hook that runs `scripts/comment-ratchet.py` after each edit, or that calls `jj` (its repo config is writable from the sandbox). `./tests/all` and CI still run the ratchet. There is no Stop hook for `./tests/all` for the same reason, and because the suite is slow. `autoMode` settings are read only from user or managed settings, not from this file, so `private_dot_claude/modify_private_settings.json` keeps one `autoMode.allow` entry in `~/.claude/settings.json` that lets auto mode run this repo's `./tests/all`; it also keeps the credential-file Read deny rules there, so they hold in every project. A new `autoMode.allow` list starts with `$defaults`, and entries you add yourself stay.

Each client routes to skills by their `SKILL.md` `name` and `description`; there is no separate routing list. Keep detailed procedures in
the corresponding `private_dot_agents/private_skills/*/SKILL.md` files instead
of copying the full catalog into secondary documentation.

Optional tool metadata lives alongside the shared skill when needed. For example, Codex UI metadata remains in `agents/openai.yaml` inside the canonical skill folder rather than in a separate client-specific copy.

### Shared Sources Of Truth

Skills should have one source of truth: the shared `private_dot_agents/private_skills/` tree. Client-specific paths should be routing only, not separate copies of skill content.

Keep tracked client config conservative as well: dangerous-mode / permission-prompt bypasses and similar safety relaxations belong in client-supported local or per-run overrides, not repo defaults. For example, prefer `codex -c 'projects."/path/to/repo".trust_level="untrusted"'` or `claude --settings /path/to/settings.json --setting-sources user,project,local` over changing tracked repo config.

For cross-cutting work, the canonical references can still live in repo-root docs instead of skill-local copies:

- `ARCHITECTURE.md`
- `docs/file-layout.md`
- `plans/README.md`
- `AGENTS.md`

### Third-Party Skills

Vendored skills are copies of upstream MIT-licensed skills that live in the shared tree like any other skill:

- Each `SKILL.md` frontmatter has `license: MIT` and `metadata.upstream` with the upstream `name` and `url`, plus the vendored `commit`. The older `grill-me` port has no recorded commit.
- Each folder has `LICENSE.txt` with the upstream copyright notice.
- Local edits stay small: rename references to match local skill names (upstream `grilling` is local `grill-me`), make Cursor-only paths and client-only tool names (such as Claude's Skill tool) client-neutral, and remove references to skills that are not vendored.
- To refresh one, diff the upstream folder between the recorded `commit` and the new commit, apply the change, keep the local edits, and update `commit`.

Current upstream sources:

- `mattpocock/skills`: `grill-me`, `grill-with-docs`, `domain-modeling`, `codebase-design`, `improve-codebase-architecture`, `tdd`, `diagnosing-bugs`, `prototype`, `handoff`, `teach`.
- `cursor/plugins` `pstack`: `unslop`, `blast-radius`, `technical-writing`, `create-verification-skill`, `maintain-verification-skill`.
- `janestreet/agent_skills`: `socratic-tutor`.

`janestreet/agent_skills` is tracked as a whole repository, with no local edits. `scripts/sync-upstream-skills.py` copies every top-level upstream folder that has a `SKILL.md`, adds the `license` and `metadata.upstream` fields (the `commit` is the last upstream commit that changed that folder), and writes `LICENSE.txt` from the upstream license. It reads upstream files as Git data and runs none of them. It stops, and writes nothing, when an upstream file is executable, a symlink, larger than 1 MiB, or has a name that chezmoi reads as an attribute (such as `dot_`, `.tmpl`, or a hidden file). It reports a skill that was removed upstream but does not delete it.

The daily `upstream-skills` workflow runs the script with `--check`. When upstream changed, it opens one issue, "Upstream agent skills changed", with the changed files and a compare link, and it updates that issue on later runs. It closes the issue when the tree matches upstream again. The workflow cannot open the pull request itself: the default Actions token cannot open pull requests or start the required checks, and the maintenance App accepts only pin-file changes. To apply an update, review the compare link, run `python3 scripts/sync-upstream-skills.py`, add an `evals/skill-routing.json` case and a line above for each new skill, run `./tests/all`, and publish through `dotfiles-push` and a pull request. To track another upstream repository as a whole, add it to `SOURCES` in the script; skills with local edits stay on the manual refresh above.

Large skills with bundled examples or tooling install as pinned chezmoi externals instead of repo copies. `anatomy` (wheresryan22/anatomy, about 12 MB) installs at `~/.agents/skills/anatomy` from a commit-pinned archive in `.chezmoiexternal.toml.tmpl`, on the workstation role only, because it needs Node.js and Chrome. Its gallery publish step runs `git` and `gh` and reads local Claude Code session logs for time and token counts. It runs only after the user approves a dry-run plan.

`modern-web-guidance` (GoogleChrome, Apache-2.0) splits in two. The skill text is vendored in `private_dot_agents/private_skills/modern-web-guidance/` with small local edits listed in its frontmatter. The guides, search index, and CLI install at `~/.local/share/modern-web-guidance` from the checksum-pinned npm tarball in `.chezmoiexternal.toml.tmpl`, on the workstation role only. Upstream runs `npx -y modern-web-guidance@latest` on each call, which downloads a new release about every 1.6 days; the local skill runs the pinned copy with `node` and `DISABLE_TELEMETRY=1`, with no network. Do not install the upstream Claude Code plugin as well: it adds a second, unpinned copy. To update, diff the upstream `SKILL.md` and CLI, then bump `npm-version` in the skill, the tarball URL, and the checksum together; `tests/test_agent_instructions.py` checks that they agree.

## Future Machine Combination Pattern

Use this pattern for maintainability:

1. Add role/profile behavior first (template/script conditions).
2. Keep shared helper logic in `dot_local/private_lib/chezmoi-helpers.sh`.
3. Keep machine-specific exceptions minimal and documented.
4. Prefer adding pinned version data in `.chezmoidata.toml` and `.chezmoiversion.toml` over ad hoc script constants.
