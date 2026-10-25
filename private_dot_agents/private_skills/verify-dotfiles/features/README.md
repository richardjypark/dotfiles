# Dotfiles verification map

This directory is the maintained source for proving the user-visible behavior of the rendered dotfiles. Read this index before you drive a run, then use the matching feature file as the recipe.

## Baseline preconditions

- `VD=~/.agents/skills/verify-dotfiles/scripts/verify-dotfiles` (or the source copy, see `../SKILL.md`).
- In the Claude Code sandbox, run every `"$VD"` command for one run with the sandbox disabled.
- Launch a fresh run from the source under test: `"$VD" --source <checkout> launch --role workstation --profile standard`. Save `RUN` and `EVIDENCE` from its output.
- `"$VD" doctor "$RUN"` prints `doctor: run is ready`.
- Never drive the real home, a real tmux server, or a run that this verification did not launch.

## Driving conventions

- Start each recipe from a fresh launch unless its preconditions say otherwise. One run can serve several recipes that do not mutate it.
- Use `"$VD" chezmoi "$RUN" NAME ...` for chezmoi, `"$VD" shell "$RUN" NAME '...'` for a login shell without a terminal, and `"$VD" tmux "$RUN" ...` for an interactive pane.
- Treat every command as literal. Keep quoted text unchanged.
- To wait for output in a pane, print a marker that the typed text does not contain: type `print -r -- STEP_""DONE`, wait for `STEP_DONE`.
- Keep `NOTMUX=1` (the helper sets it). See `zsh-startup.md` for why.

## Proof and skip reporting

- Capture the action and the result: the `.cmd` file plus `.out`, `.err`, and `.exit`, or a `.pane.txt` capture.
- For a mutation, capture a second read-only view (for example `chezmoi status` after the repair).
- Record the feature ID with each artifact name, such as `render-drift-status`.
- Report an entry point that you could not drive with the command you tried and the unmet precondition.
- Do not report an entry point as verified through a different entry point.
- Evidence can hold private local values (host aliases, user names). Keep it out of tracked files.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph about the user-visible behavior. It then has four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with verify-dotfiles`, and `Gotchas`.

## Features

- [Render and converge](./render-apply.md) covers the first apply into an empty home, repeat apply, and drift repair.
- [Role and profile gating](./role-profile.md) covers what the server role and the omarchy profile leave out.
- [Interactive zsh startup](./zsh-startup.md) covers a clean login shell, PATH order, aliases and commands, and the Herdr auto-start guard.
- [tmux status badges](./tmux-status.md) covers config load and the LOCAL, SSH, and REMOTE host badges.
- [Shared agent skill tree](./agent-skill-tree.md) covers `~/.agents/skills`, the client links, and the rendered agent guides.
