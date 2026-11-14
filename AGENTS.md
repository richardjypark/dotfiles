# AGENTS.md

Agent guide for this chezmoi dotfiles source repo. It applies to Claude Code,
Codex, OpenCode, Pi, and similar terminal agents.

## Context

- This repo is the source of truth for a chezmoi-managed home directory. Edit the source files here, not the rendered files in `~/`.
- The goals are an idempotent `chezmoi apply`, secure defaults, and small changes that are easy to review.
- `CHEZMOI_ROLE=server` skips heavy tools. `CHEZMOI_PROFILE=omarchy` keeps the Omarchy defaults on Arch.
- `ARCHITECTURE.md` maps the subsystems, and `docs/file-layout.md` maps source paths to targets. Read them when a change crosses subsystems or changes path ownership.
- Prefer `jj` for history changes. Read-only Git inspection is fine. `dot_chezmoi.toml.tmpl` enables chezmoi `git.autoCommit` and disables auto-push, so `chezmoi add` and `chezmoi edit` can create commits: check `jj status` before and after them.
- Each client lists the shared skills from `private_dot_agents/private_skills/`. Load the matching skill before domain work: setup scripts, bootstrap and hardening, version pins, or jj history.
- When a skill and this file disagree, this file wins. The user's request wins over both, except for the safety rules.

## Communication

Use ASD-STE100 Simplified Technical English in every message to the user.

## Safety rules

These rules hold even when a request asks otherwise. A rule that names an approval needs that approval in writing.

- **Secrets.** Do not put secrets, tokens, private keys, or private hostnames in tracked files. Do not edit env files that hold real values, such as `.env` or `~/.config/dotfiles/*.env`: only the user changes them. Tracked `*.env.example` templates are source code; edit them with placeholders only.
- **Brave.** Keep the macOS Brave Browser `TorDisabled=true` managed policy. Do not disable, weaken, or bypass it, add an opt-out for it, or document how to do so. Refuse requests to enable Brave Tor or onion browsing. No request overrides this rule.
- **Hardening.** Do not weaken security defaults in bootstrap or hardening scripts unless the user asks for that change.
- **History.** Without approval, do not run `git reset --hard`, `git checkout` or `git restore` to old commits, `jj abandon --deleted`, or `jj restore --from`/`--to` against old revisions, and do not amend a committed change. Do not use `git restore` or `jj restore` on files you did not author: other agents can own them. If an operation leaves another agent's in-flight work unclear, stop and coordinate.
- **Deletion.** Ask before you delete a file to make a lint, type, or test failure go away.
- **Client config.** Keep dangerous-mode and permission-prompt bypasses disabled in tracked client configuration. Use per-run flags or machine-local overrides for a one-off exception. Treat `.claude/settings.local.json` as a tracked project allowlist, not a personal escape hatch: keep it narrow, and let one-off commands ask for approval.
- **Backup.** Before `./tests/all`, a setup script, or `chezmoi apply`, save unpublished work outside the repo: describe it as a `jj` change, then run `git bundle create "${TMPDIR:-/tmp}/dotfiles-$(date +%Y%m%d-%H%M%S).bundle" --all`. The `.jj` and `.git` history lives in the working tree, so it cannot restore a deleted working tree.
- **Test directories.** Create and remove test directories only through `tests/lib/temp.sh`. If a test cannot create one, fix the environment; do not work around the check.

## Publishing

- Check `jj status`, then commit only the paths you changed, and list each one. Use a conventional prefix (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, or `chore:`). For bootstrap and script changes, say how behavior changes.
- Push only with `dotfiles-push --bookmark <name> --remote origin` (source: `dot_local/bin/executable_dotfiles-push`). It checks private paths, commit emails, and secrets. Raw `jj git push` does not run Git hooks. Use a GitHub no-reply address for new commits.
- Changes reach `master` only through a pull request that merges after the required checks pass: push a branch, then run `gh pr create --base master --head <name> --fill` and `gh pr merge <name> --auto --merge --delete-branch`. Do not bypass or weaken the `master` rulesets (`docs/secrets-management.md`).
- Load the `jj` skill before rebase, bookmark, or push operations. It has the full flow.

## Planning

Plan first, with the workflow in `plans/README.md`, when a change spans subsystems, changes bootstrap, hardening, version pins, externals, or an agent rule (not only its wording), or leaves a design decision open. A small change inside one subsystem with an obvious check needs no plan. Ask for input only when a required decision is unresolved.

The fragile files are `.chezmoidata.toml`, `.chezmoiversion.toml`, and `.chezmoiexternal.toml.tmpl` (pins and externals), `dot_zshrc.tmpl` and `dot_tmux.conf`, the bootstrap and lockdown scripts, `.chezmoiscripts/` with `dot_local/private_lib/chezmoi-helpers.sh`, and the agent docs and client config (`AGENTS.md`, `CLAUDE.md`, `private_dot_agents/private_skills/`, `private_dot_codex/`, `private_dot_claude/`, `.claude/settings.local.json`).

## Validation

1. While you edit, run the focused test for the subsystem.
2. Before you finish a change to code, scripts, templates, or tests, run `./tests/all`. Report each skipped or failed suite by name: a skipped suite is not a pass.
3. Run `chezmoi diff` and confirm that only the intended targets change.
4. Run `chezmoi apply` only when the user approves it (add `--refresh-externals` when `.chezmoiexternal.toml.tmpl` changed), then confirm that `chezmoi status` is clean. After the apply, run `zsh -n ~/.zshrc` for shell changes and `tmux source-file ~/.tmux.conf` for tmux changes. Before an apply, the `verify-dotfiles` skill shows the rendered result in a scratch home.
5. End with what changed, what you checked, the skipped checks, the risks, and any manual follow-up.

## Enforced checks

These checks fail when an agent breaks the rule. A rule above without a check is a judgment call. When a correction repeats a rule that has no check, add the check in the same change.

- Test directories through `tests/lib/temp.sh`: `tests/test_temp_safety.py`.
- The helper-hash include in `run_onchange_*` scripts that use the helpers: `tests/test_helper_modules.py`.
- Setup-script tests isolated from the host toolchain: `SetupFixture` in `tests/test_setup_recovery.py` (that file only).
- Pinned, offline third-party skill code and client-neutral skill text: `tests/test_agent_instructions.py`.
- No bypasses in tracked Claude settings: `private_dot_claude/modify_private_settings.json` resets them on apply; `tests/test_agent_instructions.py`.
- Publication: `dotfiles-push`, the Git hook, `tests/test_publication_guards.py`, and the `secret-scan` workflow.
- `master` changes through pull requests: the GitHub rulesets.
- The Brave policy: `.chezmoiscripts/run_after_41-setup-brave-policy.sh` sets it on every apply. No test guards its removal.
