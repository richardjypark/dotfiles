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

- `czu`: jj-based dotfiles update and apply.
- `czuf`: forced jj-based update with externals/tool refresh.
- `czl`: Omarchy/Arch maintenance wrapper that runs `czuf`, upgrades official Arch packages, bumps pinned stable versions, and re-applies the bumped state. Pi updates are handled by the repo’s managed pinned install during apply instead of a floating global npm update.
- On macOS, uv setup is Homebrew-first during apply/refresh; pinned GitHub artifact install remains fallback when Homebrew is unavailable.
- `czm`: macOS maintenance wrapper that runs `czuf` in a Homebrew-maintenance mode, performs the dedicated Homebrew upgrade/cleanup phase, bumps pinned versions, and re-applies only when the bump changed tracked pin files.
- `czvc`: managed `~/.local/bin/czvc` command that checks pinned versions and exits non-zero when API/network errors make the check incomplete.
- `czb`: managed `~/.local/bin/czb` command that bumps pinned versions with preflight/apply/verify transaction checks and rollback on failure.
- `czu`/`czuf` rebase to `[git].defaultBranch` from `.chezmoidata.toml` (with remote-head fallback) to avoid hardcoding branch names.
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

Skills are shared across both Claude Code and Codex CLI so that either tool follows the same repo conventions. Codex is the canonical planning path, but the skill folders themselves should follow a tool-agnostic structure:

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

- `~/.codex/skills` → symlink to `~/.agents/skills`
- `~/.claude/skills` → symlink to `~/.agents/skills`

Shared skills currently include:

- `chezmoi-repo-maintainer` — Cross-cutting repo maintenance for docs, templates, shell/tmux behavior, agent instructions, and multi-subsystem changes.
- `jj` — Jujutsu version control workflows, bookmark-safe publishing, recovery, and repo interactive helpers with detailed reference material in `references/jj-reference.md`.
- `chezmoi-script-maintainer` — Create and maintain `.chezmoiscripts/*` setup scripts with `references/script-patterns.md`.
- `chezmoi-bootstrap-operator` — Bootstrap workflow operations across Omarchy and VPS paths with `references/bootstrap-matrix.md`.
- `dotfiles-version-refresh` — Update pinned tool versions and external dependencies with `references/version-map.md`.

Optional tool metadata lives alongside the shared skill when needed. For example, Codex UI metadata remains in `agents/openai.yaml` inside the canonical skill folder rather than in a separate client-specific copy.

### Shared Sources Of Truth

Skills should have one source of truth: the shared `private_dot_agents/private_skills/` tree. Client-specific paths should be routing only, not separate copies of skill content.

Keep tracked client config conservative as well: dangerous-mode / permission-prompt bypasses and similar safety relaxations belong in local untracked overrides, not repo defaults.

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
