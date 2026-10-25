---
name: verify-dotfiles
description: "Prove a change to this chezmoi dotfiles repo works the way a user meets it: render the source into a scratch home, start an interactive zsh and tmux from it, and keep evidence. Use after edits to rendered targets, shell or tmux config, .chezmoiignore role/profile rules, or the shared skill tree, when tests alone do not show the user-visible result."
---

# Verify Dotfiles

This skill drives the dotfiles as a user meets them, but in a scratch home. It never touches the real `~/`. The helper renders the selected source checkout with `chezmoi apply --exclude=scripts` into a run directory, then drives an interactive login zsh and a private tmux server from that home.

Setup scripts (`.chezmoiscripts/*`) do not run here. They install software on the real machine. To check them, use `chezmoi-script-maintainer`.

## Helper

```bash
VD=~/.agents/skills/verify-dotfiles/scripts/verify-dotfiles
"$VD" --help
```

If you changed the helper itself and did not apply yet, run the source copy:
`bash ~/.local/share/chezmoi/private_dot_agents/private_skills/verify-dotfiles/scripts/executable_verify-dotfiles`.

The helper renders `--source DIR`, else `$VERIFY_DOTFILES_SOURCE`, else `chezmoi source-path`. Pass `--source` when you work in another jj workspace. It sources `tests/lib/temp.sh` from that checkout, so every run directory comes from `new_test_temp_dir` and is removed only by `remove_test_temp_dir`.

## Sandbox rule

In the Claude Code sandbox, run every helper command for one run with the sandbox disabled, and do not mix modes:

- A cold render downloads archive externals, even with scripts excluded, and Go TLS fails in the sandbox.
- tmux cannot create its socket in the sandbox (`Operation not permitted`).
- The run directory is under `$TMPDIR`, and `$TMPDIR` differs between the two modes. The helper refuses a run directory from the other mode.

The helper writes only in its run directory and evidence directory. Other agents (Codex, Pi) can run it as is when they have network access.

## Launch

```bash
"$VD" --source ~/.local/share/chezmoi launch --role workstation --profile standard
```

- Roles: `workstation`, `server`. Profiles: `standard`, `omarchy`.
- The helper writes a private chezmoi config (`autoCommit = false`) with that role and profile, and unsets `CHEZMOI_ROLE`, `CHEZMOI_PROFILE`, and `CHEZMOI_FORCE_ZSH_LOGIN`.
- Ready means: the render exits 0, then `chezmoi status --exclude=scripts` prints nothing. The helper prints `READY <n> files`, then `RUN=<dir>` and `EVIDENCE=<dir>`. Keep both paths.
- A render takes about 30 seconds. A workstation render has about 2000 files, and a server render has about 100 fewer.
- `--cache DIR` reuses a warm chezmoi cache and adds `--refresh-externals=never`. Use it only to repeat renders quickly.
- On failure, the helper prints the tail of `launch.log` and the cleanup command.

## Doctor

Run this first, and again whenever a result looks wrong:

```bash
"$VD" doctor "$RUN"
```

It is read-only. It checks that the run belongs to this temporary base, the key targets exist, `zsh -n` passes on `~/.zshenv` and `~/.zshrc`, `chezmoi status` is clean, the source revision equals the one at launch, and the run's tmux session is alive when a tmux server exists. `FAIL source changed since launch` means the evidence would describe old source: launch a new run.

## Drive

- **chezmoi on the run**: `"$VD" chezmoi "$RUN" NAME SUBCOMMAND [ARGS]` runs `apply`, `diff`, `status`, `verify`, `managed`, `ignored`, `cat`, or `data` with this run's home, config, state, and cache. It adds `--exclude=scripts` to `apply`, `diff`, `status`, and `verify`, and refuses other subcommands.
- **Login shell without a terminal**:
  `"$VD" shell "$RUN" NAME 'COMMAND'` runs `zsh -ilc COMMAND` with `HOME` set to the scratch home, `NOTMUX=1`, and a `PATH` with no entries under the real home.
- **Interactive pane**: `"$VD" tmux "$RUN" start` starts a private tmux server on `$RUN/tmux.sock` that loads the scratch `~/.tmux.conf`, starts `zsh -il`, and waits for the shell to answer. Then:
  - `"$VD" tmux "$RUN" send 'TEXT'` types TEXT and presses Enter.
  - `"$VD" tmux "$RUN" wait 'TEXT' [SECS]` waits until the pane shows TEXT.
  - `"$VD" tmux "$RUN" capture NAME` saves the pane, the pane option `@dotfiles_status_host`, and the expanded `status-right`.
  - To watch it yourself: `tmux -S "$RUN/tmux.sock" attach -t verify`.
- To wait for command output, print a marker that the typed text does not contain, such as `print -r -- DONE_""MARK` and wait for `DONE_MARK`.

Use the feature map for recipes: [features/README.md](features/README.md).

## Evidence

Evidence lives in `$TMPDIR/verify-dotfiles-evidence/<run-id>/`, outside the run directory. Cleanup never removes it. Each run has `run.env` (source, revision, role, profile), `launch.log`, and `launch-status.txt`. `shell` adds `NAME.cmd`, `NAME.out`, `NAME.err`, and `NAME.exit`. `tmux capture` adds `NAME.pane.txt`.

Proof standards:

- Drive the user path: a rendered file, a shell the user starts, keys typed in a pane. Do not source a single repo file in isolation and call that a user proof.
- Capture the action and the result. For a mutation, also capture a second, read-only view, such as `chezmoi status` after a second apply.
- Use a stand-in only at a real external boundary, such as a shell function named `ssh` in place of a network connection. Say so in the report.
- Report every feature entry point you did not drive, with the reason.
- Rendered files can contain private values from local data (host aliases, user names). Do not paste evidence into tracked files or public places.

## Cleanup

```bash
"$VD" cleanup "$RUN"
"$VD" list
```

Cleanup stops only the tmux server on this run's socket, then removes the run directory through `remove_test_temp_dir`. It prints the kept evidence directory. Never kill tmux or zsh by process name. `list` shows runs that still exist in this mode's temporary base.

## Related

- `chezmoi-script-maintainer` for setup scripts, which this skill excludes.
- `maintain-verification-skill` to keep the feature map current after the dotfiles change.
