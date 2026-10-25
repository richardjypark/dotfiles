# Render and converge

A user runs `chezmoi apply` and gets a complete home in one pass. A second apply changes nothing. If the user edits a managed file by hand, `chezmoi status` shows the drift, and the next apply restores the managed content.

## Sub-features

- `render-first` renders the full source into an empty home and converges in one apply.
- `render-repeat` makes no change on a second apply.
- `render-drift` shows a hand edit in `chezmoi status` and restores it on apply.

## How to get to it (user POV)

- Run `chezmoi apply` on a new machine after `chezmoi init` (bootstrap paths call it too).
- Run `chezmoi apply` again after a pull, through `czu` or by hand.
- Edit a managed file in `~/`, then run `chezmoi status` and `chezmoi apply`.

## Driving it with verify-dotfiles

Preconditions:

- No run exists for this check. Launch one: `"$VD" --source <checkout> launch --role workstation --profile standard`.

- **First render.** `launch` is the first apply. Exit code `0`, then `READY <n> files` with `n` near 2000, and `$EVIDENCE/launch-status.txt` is empty.
- **Repeat apply.** Run `"$VD" chezmoi "$RUN" render-repeat apply --verbose`. Exit code `0` and `render-repeat.out` is empty: verbose apply prints a diff only when it changes a target.
- **Repeat status.** Run `"$VD" chezmoi "$RUN" render-repeat-status status`. Exit code `0` and `render-repeat-status.out` is empty.
- **Hand edit.** Append a line to a managed file: `"$VD" shell "$RUN" render-drift-edit 'print -r -- "# hand edit" >> ~/.config/shell/alias.sh'`. Exit code `0`.
- **Drift shows.** Run `"$VD" chezmoi "$RUN" render-drift-status status`. `render-drift-status.out` has the line `MM .config/shell/alias.sh`.
- **Repair.** Run `"$VD" chezmoi "$RUN" render-drift-apply apply --force`. Exit code `0`.
- **Proof.** Run `"$VD" chezmoi "$RUN" render-drift-after status` and `"$VD" shell "$RUN" render-drift-grep 'grep -c "hand edit" ~/.config/shell/alias.sh'`. The status output is empty, and grep prints `0` with exit code `1`.

## Gotchas

- Setup scripts are excluded. A clean status here says nothing about `.chezmoiscripts/*`.
- Archive externals download even with scripts excluded. A cold render needs the network.
- `apply` without `--force` asks before it overwrites a hand edit. The helper closes stdin, so that apply prints the question, then `chezmoi: .config/shell/alias.sh: EOF`, and exits `1`. Use `--force` only in the repair step.
- `launch` fails with `render did not converge` when one apply cannot reach a clean status. That is a real finding about the source; do not rerun apply to hide it.
