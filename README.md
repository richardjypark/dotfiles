# github.com/richardjypark/dotfiles

Richard Park's dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Omarchy Quickstart

This repo includes a role-based bootstrap for fresh Omarchy (Arch-based) machines.

1. Install `chezmoi` and initialize:

```bash
sudo pacman -S --noconfirm --needed chezmoi git curl
chezmoi init --apply richardjypark
```

2. Optional: create a local private env file for non-public values:

```bash
mkdir -p ~/.config/dotfiles
cp ~/.local/share/chezmoi/scripts/bootstrap-private-env.example ~/.config/dotfiles/bootstrap-private.env
$EDITOR ~/.config/dotfiles/bootstrap-private.env
chmod 600 ~/.config/dotfiles/bootstrap-private.env
```

3. Run bootstrap for your role:

```bash
# Personal workstation
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation

# Personal server
~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server
```

`--role workstation` installs the workstation package set, including Jujutsu (`jj`/`jujutsu`).

4. For server role, use two-phase hardening:

```bash
# First verify SSH over Tailscale works, then lock down:
sudo ~/.local/share/chezmoi/scripts/server-lockdown-tailscale.sh
```

`CHEZMOI_ROLE` is set automatically by the bootstrap script (`workstation` or `server`) so templates can skip server-unneeded tooling.

## Setup Profiles (What To Run Where)

Use this matrix to pick the right flow for each machine.

| Machine type | Bootstrap command | Ongoing chezmoi command | Notes |
| --- | --- | --- | --- |
| Omarchy personal machine (pinned Omarchy baseline) | `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation` | `chezmoi update` | Chezmoi manages Omarchy-style Ghostty/Starship + your zsh/tmux stack, and bootstrap installs `jujutsu`. |
| Omarchy personal machine (temporary skip of shell/terminal targets) | `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role workstation` | `CHEZMOI_PROFILE=omarchy chezmoi update` | Skips managed terminal/shell targets and uses local files as-is. |
| Omarchy server | `~/.local/share/chezmoi/scripts/bootstrap-omarchy.sh --role server` | `CHEZMOI_ROLE=server chezmoi update` | Includes server package set and server-specific template/script exclusions. |
| Vultr server (legacy fallback behavior) | Use `bootstrap-vps.sh` for Debian/Ubuntu, or Omarchy server flow on Arch | `CHEZMOI_ROLE=server chezmoi update` | Some exclusions also key off hostname `vultr` for backward compatibility. |

## Bootstrap Flags and Environment

`scripts/bootstrap-omarchy.sh` supports:

- `--role workstation|server` (required)
- `--repo <chezmoi-repo>` (optional, default: `richardjypark`)
- `-h`, `--help`

Environment variables used by `scripts/bootstrap-omarchy.sh`:

- `PRIVATE_ENV_FILE` path to local, untracked env file (default: `~/.config/dotfiles/bootstrap-private.env`)
- `TRUST_ON_FIRST_USE_INSTALLERS=1` allows setup scripts that use remote installers
- `DOTFILES_REPO` alternative way to set the chezmoi repo target

Optional variables typically loaded from `bootstrap-private.env`:

- `BOOTSTRAP_GIT_EMAIL`
- `BOOTSTRAP_SSH_PUBLIC_KEY`
- `BOOTSTRAP_SSH_PUBLIC_KEY_FILE`
- `BOOTSTRAP_HOST_ALIAS`

## Chezmoi Role/Profile Switches

- `CHEZMOI_ROLE=server` enables server behavior in templates and `.chezmoiignore` (skips local-dev tooling setup)
- `CHEZMOI_PROFILE=omarchy` skips managed shell/terminal targets (escape hatch mode)
- `~/.config/nvim` is managed by chezmoi (pinned baseline from this machine)
- `TRUST_ON_FIRST_USE_INSTALLERS=1` is required for installer-based setup scripts during `chezmoi apply/update`

Examples:

```bash
# Omarchy personal machine, temporary skip mode
CHEZMOI_PROFILE=omarchy chezmoi apply
CHEZMOI_PROFILE=omarchy chezmoi update

# Server apply/update
CHEZMOI_ROLE=server chezmoi apply
CHEZMOI_ROLE=server chezmoi update

# Server apply/update with installer trust
CHEZMOI_ROLE=server TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi update
```

### Omarchy Baseline Refresh (Manual, Pinned)

This repo pins Omarchy-flavored defaults so updates are intentional. To refresh from current Omarchy files:

```bash
cp ~/.local/share/omarchy/config/ghostty/config ~/.local/share/chezmoi/private_dot_config/ghostty/config
cp ~/.local/share/omarchy/config/starship.toml ~/.local/share/chezmoi/private_dot_config/starship.toml
chezmoi add ~/.config/nvim
chezmoi diff
chezmoi apply
```

Use `CHEZMOI_PROFILE=omarchy` only if you explicitly want to skip those managed targets.

## Secrets Policy

This repository is public. Do not commit secrets, private keys, tokens, or host-specific sensitive data.

- Put sensitive bootstrap inputs in `~/.config/dotfiles/bootstrap-private.env` (local, untracked).
- Supported optional variables:
  - `BOOTSTRAP_GIT_EMAIL`
  - `BOOTSTRAP_SSH_PUBLIC_KEY`
  - `BOOTSTRAP_SSH_PUBLIC_KEY_FILE`
  - `BOOTSTRAP_HOST_ALIAS`

## Generic Install

If you only want a normal `chezmoi` install flow:

```bash
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b $HOME/.local/bin
    chezmoi init richardjypark
    chezmoi update
```

## Shell Startup Troubleshooting

Verify your login shell:

```bash
getent passwd "$USER" | cut -d: -f7
```

Expected value: `/usr/bin/zsh` (or `/bin/zsh` on some systems).

If it is still bash, fix it with:

```bash
chsh -s "$(command -v zsh)" "$USER"
```

If your system requires sudo:

```bash
sudo chsh -s "$(command -v zsh)" "$USER"
```

## Performance Optimizations

This dotfiles setup features a highly optimized `chezmoi` experience, ensuring that `chezmoi apply` and `chezmoi update` operations are exceptionally fast after the initial setup. Key improvements include:

- **Drastic Speed Increase**: Subsequent runs are **~95% faster** (e.g., from 1-2 minutes down to <3 seconds).
- **Quiet by Default**: Console output is minimized to only essential messages (errors, critical operations), eliminating I/O bottlenecks.
- **Smart Script Execution**: Scripts use early exit conditions and state tracking (`~/.cache/chezmoi-state`) to avoid redundant work.
- **Efficient Network Usage**: Package installations (npm, apt-get) and git operations are optimized and their output is suppressed in quiet mode.
- **Cross-Platform Compatibility**: Enhanced detection for package managers (apt-get, brew) and robust error handling.

**Core Optimization Techniques:**

1.  **Early Exit Conditions**: All setup scripts first check if their intended operations (e.g., package installation, directory creation) are already completed. If so, they exit immediately.
2.  **Console Output Management**: A `VERBOSE` environment variable controls output. By default, scripts are quiet. Set `VERBOSE=true` for detailed logs.
3.  **State Tracking**: A simple file-based system in `~/.cache/chezmoi-state` remembers completed setup tasks, preventing re-runs.

### Verbose Mode for Debugging

While scripts are quiet by default for speed, you can enable detailed logging for debugging or to see all operations:

```bash
# Enable verbose output for the current session
export VERBOSE=true
chezmoi apply

# Enable for a single command
VERBOSE=true chezmoi apply

# Create a convenient alias (optional, add to your .zshrc or .bashrc)
alias chezmoi-verbose='VERBOSE=true chezmoi'
chezmoi-verbose apply
```

Performance behavior is primarily implemented in `.chezmoiscripts/` using early exits and state tracking.

## Debian/Ubuntu VPS Bootstrap Defaults

`bootstrap-vps.sh` now defaults to a safer posture:

- No passwordless sudo unless explicitly enabled.
- No automatic copy of root SSH keys unless explicitly enabled.
- No remote `curl | sh` installers unless explicitly trusted.

Example secure-first run:

```bash
USERNAME=rich DOTFILES_REPO=https://github.com/richardjypark/dotfiles.git ./bootstrap-vps.sh
```

If you intentionally want convenience-first behavior (less secure), opt in explicitly:

```bash
ALLOW_PASSWORDLESS_SUDO=1 \
COPY_ROOT_AUTH_KEYS=1 \
TRUST_ON_FIRST_USE_INSTALLERS=1 \
USERNAME=rich DOTFILES_REPO=https://github.com/richardjypark/dotfiles.git \
./bootstrap-vps.sh
```

For regular `chezmoi apply`, setup scripts that rely on remote installers also require explicit trust:

```bash
TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply
```

## Tmux Configuration

This dotfiles repository includes a tmux configuration with:

- Auto-start tmux when opening a terminal
- Session persistence with tmux-resurrect and tmux-continuum
- Vi mode keybindings
- Mouse support
- Custom key bindings for easier navigation

### Key Bindings

| Shortcut          | Action                    |
| ----------------- | ------------------------- |
| Alt + h/j/k/l     | Navigate between panes    |
| Prefix + \|       | Split window vertically   |
| Prefix + -        | Split window horizontally |
| Prefix + Ctrl + s | Save session manually     |
| Prefix + Ctrl + r | Restore session manually  |

The default prefix key is `Ctrl + b`.

### Session Management

Sessions are automatically saved every 15 minutes and restored when tmux starts.

## Installed Tools

This dotfiles configuration includes the following tools:

- **Shell**: Zsh with Oh My Zsh
- **Terminal Multiplexer**: Tmux with TPM (Tmux Plugin Manager)
- **Tmux Plugins**:
  - tmux-resurrect (session saving)
  - tmux-continuum (automatic session management)
- **Theme**: Agnoster
- **Zsh Plugins**:
  - zsh-syntax-highlighting
  - zsh-autosuggestions
  - fzf (fuzzy finder)
  - git
  - ssh-agent
  - terraform
- **Node.js Environment**:
  - nvm (Node Version Manager)
- **AI Coding Agents**:
  - Claude Code (claude.ai/install.sh)
  - Codex CLI (`brew install --cask codex` or official release binaries)
- **Terminal**: Ghostty

## Applying Changes and Testing Plugins

To apply changes made to your dotfiles (such as adding the `terraform` Oh My Zsh plugin) and test them, follow these steps:

1. **Apply the Change with chezmoi**

   Run the following command in your terminal:

   ```sh
   chezmoi apply
   ```

   This updates your real dotfiles (like `~/.zshrc`) with the latest changes from your chezmoi-managed templates.

2. **Reload Your Zsh Configuration**

   After applying, reload your shell configuration to activate the new plugin without restarting your terminal:

   ```sh
   source ~/.zshrc
   ```

3. **Test the Terraform Plugin**

   - Type `terraform` and press Tab twice. You should see Terraform command completions.
   - You can also check if the plugin is loaded by running:

     ```sh
     echo $plugins
     ```

     You should see `terraform` listed among the plugins.
