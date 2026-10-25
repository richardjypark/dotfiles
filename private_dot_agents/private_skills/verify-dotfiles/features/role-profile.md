# Role and profile gating

The saved role and profile decide what lands in the home. The `server` role leaves out workstation tooling. The `omarchy` profile keeps Omarchy's own terminal, prompt, and tmux defaults by leaving those targets unmanaged.

## Sub-features

- `role-server` leaves out workstation-only targets.
- `role-workstation` includes them.
- `profile-omarchy` leaves the Ghostty config, the starship config, and `~/.tmux.conf` unmanaged.

## How to get to it (user POV)

- Bootstrap saves the role and profile (`scripts/set-chezmoi-local-data.py`), then runs apply.
- Run apply with `CHEZMOI_ROLE=server` or `CHEZMOI_PROFILE=omarchy` for one run.

## Driving it with verify-dotfiles

Preconditions:

- Two runs from the same source: `"$VD" --source <checkout> launch --role workstation --profile standard` (`RUN_WS`) and `"$VD" --source <checkout> launch --role server --profile standard` (`RUN_SRV`). For the profile check, a third run with `--role workstation --profile omarchy` (`RUN_OM`).

- **Workstation targets.** Run `"$VD" chezmoi "$RUN_WS" role-ws-managed managed`. The output has `.agents/skills/anatomy` and `.config/mise/config.toml`.
- **Server targets.** Run `"$VD" chezmoi "$RUN_SRV" role-srv-managed managed`. The output has neither `.agents/skills/anatomy` nor `.config/mise/config.toml`.
- **Server zsh plugins.** Run `"$VD" shell "$RUN_SRV" role-srv-plugins 'print -rl -- $plugins'`. The output has `git`, `zsh-autosuggestions`, and `zsh-syntax-highlighting`, and has no `terraform` and no `ansible`. The same command on `RUN_WS` shows `terraform` and `ansible`.
- **Omarchy profile.** Run `"$VD" chezmoi "$RUN_OM" profile-om-ignored ignored`. The output has `.config/ghostty/config`, `.config/starship.toml`, and `.tmux.conf`. `"$VD" shell "$RUN_OM" profile-om-tmux 'test -e ~/.tmux.conf'` exits `1`.
- **Proof.** Keep the `managed` and `ignored` outputs of each run side by side in the evidence.

## Gotchas

- The helper unsets `CHEZMOI_ROLE` and `CHEZMOI_PROFILE`, so the run uses only `--role` and `--profile`.
- Opt-in markers under `~/.config/dotfiles/*.enabled` (Pi CLI, OpenRouter agent, Hermes) change the render. A fresh scratch home has none.
- The omarchy profile also changes Linux-only systemd units. On macOS those stay ignored for every profile.
- `.chezmoiignore` is the final authority; read it when a target appears or disappears unexpectedly.
