# Interactive zsh startup

A new terminal starts an interactive login zsh that loads the managed shell stack with no error output. Managed commands and aliases are ready, the managed tool paths come first on `PATH`, and the shell starts Herdr unless the user opts out.

## Sub-features

- `zsh-clean` starts a login shell with exit code `0` and no stderr.
- `zsh-path` puts `~/.local/share/mise/shims` and `~/.local/bin` first on `PATH`.
- `zsh-commands` defines the `eza` aliases and the managed `cz*` commands.
- `zsh-herdr-guard` keeps the shell in zsh when `NOTMUX=1` is set.

## How to get to it (user POV)

- Open a terminal (Ghostty starts `zsh -il`).
- Start a nested shell with `zsh -il`.

## Driving it with verify-dotfiles

Preconditions:

- A ready workstation run (`"$VD" doctor "$RUN"` passes).

- **Clean start.** Run `"$VD" shell "$RUN" zsh-clean 'print -r -- STARTED'`. Exit code `0`, `zsh-clean.out` is `STARTED`, and `zsh-clean.err` is empty.
- **PATH order.** Run `"$VD" shell "$RUN" zsh-path 'print -rl -- $path[1,2]'`. The two lines are `$RUN/home/.local/share/mise/shims` and `$RUN/home/.local/bin`.
- **Aliases and commands.** Run `"$VD" shell "$RUN" zsh-commands 'alias ll la lt ls; whence -w czu czm czb chezmoi-health-check'`. The aliases expand to `eza ... --group-directories-first --icons=auto`, and `whence` reports `czu: function`, `czm: command`, `czb: alias`, `chezmoi-health-check: command`.
- **Herdr guard.** Run `"$VD" shell "$RUN" zsh-herdr-guard 'print -r -- SHELL_KEPT'`. Exit code `0` and the output is `SHELL_KEPT`.
- **Interactive proof.** Start a pane with `"$VD" tmux "$RUN" start`, then `"$VD" tmux "$RUN" capture zsh-pane`. The pane shows the prompt after `VERIFY_READY` and no error lines.

## Gotchas

- Never unset `NOTMUX` in a run. `private_dot_config/shell/path.sh` adds `/opt/homebrew/bin` again, so a stub `herdr` earlier on `PATH` does not win, and the real `herdr` starts with the scratch home. Without a terminal it stops with `cannot attach without a usable terminal`; in a pane it takes over the pane. The auto-start branch itself is not covered here.
- On macOS, `/etc/zprofile` runs `path_helper` in login shells and moves `/etc/paths` entries before Homebrew. The repo does not manage `~/.zprofile`, so in a scratch home `git` resolves to `/usr/bin/git`. Compare with the real home before you call this a regression.
- The helper drops `PATH` entries under the real home, so tools that only the real home has (for example `uv`, `chezmoi`, mise-managed Node) are absent in the scratch shell. Their completions and caches are skipped.
- `zsh -ilc` has no terminal, so ZLE widgets and key bindings do not load. Use the tmux pane for anything that needs them.
