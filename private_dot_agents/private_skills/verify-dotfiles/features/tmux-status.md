# tmux status badges

tmux loads the managed config and shows a context badge and a host badge on the right of the status line. zsh hooks set the badge for each pane: `LOCAL` in a local shell, `SSH` while an outbound `ssh` or `mosh` command runs, and `REMOTE` in a shell reached over SSH.

## Sub-features

- `tmux-load` starts a server with the managed `~/.tmux.conf` and shows the expanded `status-right`.
- `tmux-badge-local` shows `LOCAL` and the local host alias.
- `tmux-badge-ssh` shows `SSH` and the masked target while `ssh <host>` runs, then returns to `LOCAL`.
- `tmux-badge-remote` shows `REMOTE` in a shell that has `SSH_CONNECTION`.

## How to get to it (user POV)

- Start tmux in a terminal on the standard profile.
- Type `ssh <host>` in a pane.
- Log in to a host over SSH and start zsh there.

## Driving it with verify-dotfiles

Preconditions:

- A ready workstation run on the standard profile (the omarchy profile has no `~/.tmux.conf`).
- The sandbox is disabled for these commands.

- **Load.** Run `"$VD" tmux "$RUN" start`. It prints `tmux ready: tmux -S $RUN/tmux.sock attach -t verify`.
- **Local badge.** Run `"$VD" tmux "$RUN" capture tmux-badge-local`. Under `--- @dotfiles_status_host (pane) ---` the value has ` LOCAL ` followed by a host alias, and the expanded `status-right` adds the time and date.
- **SSH badge.** Replace the network with a stand-in, then type the user command: `"$VD" tmux "$RUN" send 'ssh() { sleep 4; print -r -- SSH_""DONE; }'`, `"$VD" tmux "$RUN" send 'ssh lab-box'`, wait about 1.5 seconds, then `"$VD" tmux "$RUN" capture tmux-badge-ssh`. The pane option has ` SSH ` followed by ` remote ` (a host that is not in the alias file is masked as `remote`).
- **Back to local.** Run `"$VD" tmux "$RUN" wait SSH_DONE 10`, then `"$VD" tmux "$RUN" capture tmux-badge-ssh-done`. The pane option has ` LOCAL ` again.
- **Remote badge.** Run `"$VD" tmux "$RUN" send "SSH_CONNECTION='100.64.0.9 50000 100.64.0.1 22' zsh -il"`, then `"$VD" tmux "$RUN" send 'print -r -- INNER_""READY'`, `"$VD" tmux "$RUN" wait INNER_READY 20`, and `"$VD" tmux "$RUN" capture tmux-badge-remote`. The pane option has ` REMOTE `. Type `exit` to leave the inner shell.
- **Proof.** The four `.pane.txt` files show each badge with the command that caused it.

## Gotchas

- The tmux server must start with the scratch `HOME`. The helper does this. A server started with the real `HOME` expands `~/.tmux/plugins` to the real home.
- TPM and its plugins (resurrect, continuum, yank) are installed by a setup script, so they are absent in a scratch home. Do not verify plugin behavior here.
- The badge comes from `precmd` and `preexec` hooks. A capture taken before the first prompt has no pane option yet.
- `send` types into the pane before the prompt is ready; the typed text then shows above the prompt. Wait for a marker before you capture.
- Host aliases come from the private alias file. Do not copy alias values into tracked files.
- F12 nested-session toggling needs an attached client and is not covered by a detached run.
