# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a chezmoi-managed dotfiles repository optimized for performance with sophisticated state tracking and external resource management. The dotfiles configure Zsh with Oh My Zsh, Starship prompt (with native Jujutsu support), Tmux with session persistence, and development tools (Node.js via NVM, Python via uv, fzf, Jujutsu, Claude Code, Tailscale).

## Core Architecture

**Chezmoi Structure:**
- Source directory: `~/.local/share/chezmoi/` (this repository)
- Target directory: `~/` (user's home directory)
- File naming convention:
  - `dot_` prefix → `.` (e.g., `dot_zshrc` → `~/.zshrc`)
  - `private_` prefix → 0600 permissions
  - `.tmpl` suffix → template files processed with data from `.chezmoidata.toml`

**Key Configuration Files:**
- `.chezmoi.toml` - Main chezmoi settings (git auto-commit, diff/merge tools)
- `.chezmoiexternal.toml` - External dependencies (Oh My Zsh, plugins, fzf, nvm)
- `.chezmoidata.toml` - Template data (tool versions, npm packages)
- `.chezmoiversion.toml` - Version pinning for external tools (fzf v0.67.0)

**External Resources:** Managed via `.chezmoiexternal.toml` with 168h refresh periods:
- Oh My Zsh (archive pinned to an explicit commit)
- zsh-syntax-highlighting and zsh-autosuggestions (archives pinned to release tags)
- fzf (git-repo pinned to v0.67.0)
- nvm (archive v0.40.3)

## Common Commands

**Applying changes:**
```bash
chezmoi apply                    # Apply all changes
chezmoi apply --verbose          # Apply with detailed output
VERBOSE=true chezmoi apply       # Scripts with verbose output
chezmoi apply --refresh-externals # Force refresh external resources
```

**Editing dotfiles:**
```bash
chezmoi edit ~/.zshrc            # Edit in source directory
chezmoi cd                       # Change to source directory
chezmoi diff                     # See pending changes
```

**Managing state:**
```bash
chezmoi status                   # Check status
chezmoi update                   # Pull from git and apply
chezmoi git -- status            # Run git commands in source
```

**Testing changes:**
```bash
source ~/.zshrc                  # Reload shell configuration
exec zsh                         # Restart shell
```

**Profiling shell startup:**
```bash
ZSH_PROFILE_STARTUP=1 exec zsh   # Profile with detailed checkpoints
zsh_startup_time                 # Quick benchmark (5 runs average)
zsh_profile_report               # Show last profiling results
```

## Performance Optimization System

The repository uses a sophisticated state tracking system to achieve ~95% speed improvement on subsequent runs (from 1-2 minutes to <3 seconds).

**State Tracking:**
- State files stored in `~/.cache/chezmoi-state/`
- Scripts check completion state before running
- Controlled by `VERBOSE` environment variable (default: false)

**Script Execution Order:**
1. `run_before_00-state-tracker.sh` - Initialize state tracking
2. `run_before_00-prerequisites.sh` - Install system packages (apt-get, git, curl, etc.)
3. `run_before_01-setup-omz.sh` - Set up Oh My Zsh
4. `run_after_12-setup-starship.sh` - Install Starship prompt
5. `run_after_20-setup-fzf.sh` - Install fzf from repository
6. `run_after_25-setup-uv.sh.tmpl` - Install Python uv package manager
7. `run_after_26-setup-jj.sh` - Install Jujutsu (jj) version control
8. `run_after_30-setup-node.sh.tmpl` - Set up Node.js via NVM
9. `run_after_30-change-shell.sh` - Change default shell to zsh
10. `run_after_35-setup-claude-code.sh` - Install Claude Code
11. `run_after_37-setup-tailscale.sh` - Install Tailscale VPN
12. `run_after_40-setup-tmux.sh` - Set up Tmux Plugin Manager
13. `run_after_99-performance-summary.sh` - Show performance summary

**Script Patterns:**
- Early exit if task already completed
- Quiet by default (use `VERBOSE=true` for debugging)
- Use `vecho()` for verbose output, `eecho()` for essential output
- Check for existing installations before running

## Shell Configuration

**Multi-file shell setup:**
- `~/.zshenv` - Loaded for ALL shells (NVM, Bun, Cargo paths)
- `~/.zshrc` - Interactive shells only (Oh My Zsh, plugins, Starship init)
- `~/.config/starship.toml` - Starship prompt configuration (modules, colors, layout)
- `~/.config/shell/*.sh` - Modular configurations:
  - `path.sh` - PATH modifications
  - `alias.sh` - Custom aliases
  - `env.sh` - Environment variables
  - `history.sh` - History configuration
  - `fzf.sh` - fzf key bindings and completion
  - `zsh-fix.sh` - IFS fixes for Oh My Zsh compatibility
  - `gpg.sh` - GPG configuration
  - `profile.sh` - Shell startup profiling utilities

**ZSH Plugins (via Oh My Zsh):**
- git, terraform, ansible, ssh-agent, tmux
- zsh-autosuggestions, zsh-syntax-highlighting

**Prompt (Starship):**
- Starship replaces the Agnoster Oh My Zsh theme for native Jujutsu (jj) support
- Configuration: `~/.config/starship.toml` (source: `private_dot_config/starship.toml`)
- SSH host privacy: generic hostnames (server1-4) via `STARSHIP_SSH_HOST` env var
- Modules: username, hostname, directory, git, jj_status, python virtualenv, cmd_duration
- Multiline prompt with blue `❯` (success) / red `❯` (error)

**Shell Startup Profiling:**

Enable profiling to identify slow startup components:
```bash
# Profile startup with detailed checkpoints
ZSH_PROFILE_STARTUP=1 exec zsh

# Quick benchmark (5 runs, shows average)
zsh_startup_time

# View last profiling results
zsh_profile_report
```

Profiling tracks timing for:
- zshenv loading (NVM, paths, environment setup)
- zsh-fix.sh loading
- Oh My Zsh initialization
- Host detection (SSH/local)
- NVM bash completion
- Additional shell configs (~/.config/shell/*.sh)
- Starship init
- Completions (bun, uv)

Results show:
- Total startup time
- Individual checkpoint timings with deltas
- Top 5 slowest sections

Typical startup times:
- Excellent: < 200ms
- Good: < 500ms
- Acceptable: < 1s
- Needs optimization: > 1s

## Tmux Configuration

**Configuration files:**
- `dot_tmux.conf` → `~/.tmux.conf` - Main tmux configuration
- `dot_zshrc.tmpl` - Auto-start logic at end of file
- `.chezmoiscripts/run_after_40-setup-tmux.sh` - Installs tmux and TPM

**Auto-start behavior:**
- Tmux auto-starts for interactive shells in `~/.zshrc`
- Skipped when: inside SSH (`$SSH_TTY`), in VSCode (`$TERM_PROGRAM`), already in tmux (`$TMUX`), or `NOTMUX=1`
- Uses `exec tmux new-session -A` to attach to existing session or create new one

**Session persistence (via plugins):**
- `tmux-resurrect` - Manual save/restore of sessions
- `tmux-continuum` - Automatic save every 15 minutes, auto-restore on tmux start
- Processes restored: vim, nvim, less, more, tail, top, htop, man, ssh
- Pane contents NOT captured (reduces session file size)

**Terminal settings:**
- `tmux-256color` terminal type (better italics/strikethrough/truecolor)
- RGB color support enabled
- Focus events enabled (for Vim/Neovim integration)
- Escape time: 10ms (reduces delay for Vim mode switching)
- History limit: 10,000 lines
- Bell monitoring disabled (prevents `!` indicator in window names)

**Window/pane numbering:**
- Windows and panes start at index 1 (not 0)
- Windows automatically renumber when one is closed

**Status bar:**
- SSH sessions: Red background (`colour52`) with hostname displayed
- Local sessions: Green background (`colour22`)
- Right side shows: time, date (and hostname for SSH)

**Custom keybindings:**
- `Alt + h/j/k/l` - Navigate panes (vim-style, no prefix needed)
- `Prefix + |` - Split window vertically (side-by-side panes)
- `Prefix + -` - Split window horizontally (stacked panes)
- `Prefix + Ctrl + s` - Manual save session (tmux-resurrect)
- `Prefix + Ctrl + r` - Manual restore session (tmux-resurrect)

**Plugin management (TPM):**
- Plugins installed to `~/.tmux/plugins/`
- Install new plugins: Add to `~/.tmux.conf`, then `Prefix + I`
- Update plugins: `Prefix + U`
- Uninstall removed plugins: `Prefix + Alt + u`

**Troubleshooting:**
```bash
# Disable auto-start for current session
export NOTMUX=1

# Reload tmux config
tmux source-file ~/.tmux.conf

# Check if tmux is running
tmux ls

# Kill all tmux sessions
tmux kill-server

# Force reinstall TPM and plugins
rm -rf ~/.tmux/plugins && chezmoi apply
```

## Version Management

**Updating tool versions:**
1. Edit `.chezmoidata.toml` for NVM/Node.js/npm packages
2. Edit `.chezmoiversion.toml` for fzf version
3. Edit `.chezmoiexternal.toml` for Oh My Zsh plugins or external repos
4. Run `chezmoi apply --refresh-externals` to update

**Current pinned versions:**
- fzf: v0.67.0 (pinned to avoid toggle-raw error on Linux)
- nvm: v0.40.3
- Node.js: lts/* (latest LTS)

## Development Workflow

**Modifying templates:**
- Template files use `.tmpl` suffix and Go template syntax
- Access data with `{{ .nvm.version }}`, `{{ .python.version }}`, etc.
- Test templates: `chezmoi execute-template < file.tmpl`

**Adding new external tools:**
1. Add entry to `.chezmoiexternal.toml`
2. Set refresh period (typically "168h" for weekly)
3. Create setup script in `.chezmoiscripts/` if needed
4. Use naming convention: `run_after_NN-setup-toolname.sh`

**Bypassing auto-start features:**
- Tmux: Set `NOTMUX=1` environment variable
- Can be set in IDE terminal settings or per-session

## Important Notes

- **Git auto-commit enabled:** Changes in source directory auto-commit (`.chezmoi.toml`)
- **No auto-push:** Manual push required for backup
- **State files:** Clear `~/.cache/chezmoi-state/` to force script re-runs
- **External refresh:** Weekly by default (168h), use `--refresh-externals` to force
- **fzf version pinned:** v0.67.0 to avoid errors; update carefully in `.chezmoiversion.toml`

## Production Server Optimization

When chezmoi is applied on a production server (detected by hostname), certain development tools are automatically skipped:

**Skipped on hostname `vultr`:**
- Node.js/NVM setup (`run_after_30-setup-node.sh.tmpl` via `.chezmoiignore`)
- NVM external resource (conditional in `.chezmoiexternal.toml.tmpl`)
- Bun (`run_after_27-setup-bun.sh`)
- Homebrew (`run_after_10-setup-homebrew.sh`)
- Ansible (`run_after_27-setup-ansible.sh`)

This keeps production servers lean - builds happen locally and are deployed via Ansible/rsync.

**To add more server hostnames:**
Edit `.chezmoiignore` and `.chezmoiexternal.toml.tmpl`, extending the hostname conditions:
```
{{ if or (eq .chezmoi.hostname "vultr") (eq .chezmoi.hostname "other-server") }}
```

**Tools still installed on servers:**
- Oh My Zsh with plugins (zsh-syntax-highlighting, zsh-autosuggestions)
- Starship (prompt)
- fzf (fuzzy finder)
- uv (Python)
- jj (version control)
- Claude Code
- Tailscale
- Tmux

## VPS Bootstrap Script

`bootstrap-vps.sh` provisions a fresh Debian/Ubuntu VPS with hardening and dotfiles. It lives in the repo root but is not managed by chezmoi (no chezmoi naming prefix). It must be copied to the server manually since it installs chezmoi itself.

**Usage:**
```bash
# Copy to server and run as root
scp bootstrap-vps.sh root@<vps-ip>:/root/
ssh root@<vps-ip>
USERNAME=rich DOTFILES_REPO=https://github.com/richardjypark/dotfiles.git ./bootstrap-vps.sh
```

**What it does (in order):**
1. Validates root, OS (Debian/Ubuntu), network connectivity
2. `apt update` + `dist-upgrade`
3. Creates swap (default 2GB), sets timezone/locale to UTC/en_US.UTF-8
4. Creates non-root user with passwordless sudo, copies root's SSH keys
5. Installs Tailscale, sets `--operator` for non-root user access
6. Hardens SSH (key-only auth, removes weak host keys, Ed25519 + RSA only)
7. Configures UFW (deny incoming, allow SSH; optionally lock to `tailscale0`)
8. Kernel hardening via sysctl (syncookies, no redirects, rp_filter)
9. Enables unattended security upgrades
10. Configures fail2ban for SSH (whitelists Tailscale CGNAT `100.64.0.0/10`)
11. Installs chezmoi to `/usr/local/bin` and applies dotfiles as the non-root user
12. Runs 12-point verification and prints summary

**Configuration (all via environment variables):**

| Variable | Default | Purpose |
|---|---|---|
| `USERNAME` | `rich` | Non-root user to create |
| `DOTFILES_REPO` | *(must be set)* | Chezmoi dotfiles git URL |
| `SSH_PORT` | `22` | SSH listen port |
| `SWAP_SIZE_MB` | `2048` | Swap file size |
| `VERBOSE` | `false` | Detailed output |
| `DISABLE_ROOT_LOGIN` | `0` | Set to `1` after confirming user SSH works |
| `LOCK_SSH_TO_TAILSCALE` | `0` | Set to `1` after confirming Tailscale works |
| `MAX_AUTH_TRIES` | `3` | SSH max auth attempts |
| `F2B_MAXRETRY` | `3` | fail2ban max retries before ban |
| `F2B_FINDTIME` | `10m` | fail2ban observation window |
| `F2B_BANTIME` | `1h` | fail2ban ban duration |

**Phased lockdown (run the script multiple times):**
```bash
# 1. First run — everything open, verify SSH as your user
USERNAME=rich DOTFILES_REPO=https://github.com/you/dotfiles.git ./bootstrap-vps.sh

# 2. Disable root login after confirming user SSH works
USERNAME=rich DOTFILES_REPO=... DISABLE_ROOT_LOGIN=1 ./bootstrap-vps.sh

# 3. Lock SSH to Tailscale after confirming tailscale is connected
USERNAME=rich DOTFILES_REPO=... DISABLE_ROOT_LOGIN=1 LOCK_SSH_TO_TAILSCALE=1 ./bootstrap-vps.sh
```

**Important notes:**
- Script is idempotent — subsequent runs skip completed steps
- All output logged to `/var/log/bootstrap.log` (permissions 600)
- fail2ban whitelists all Tailscale IPs (`100.64.0.0/10`) to prevent lockout
- chezmoi installer may ignore `-b /usr/local/bin`; the script detects this and copies the binary from `~/.local/bin` if needed
- Update SSH config to use the Tailscale IP after locking down:
  ```
  Host vps
      HostName 100.x.x.x    # Tailscale IP
      User rich
      IdentityFile ~/.ssh/id_ed25519_key
      IdentitiesOnly yes
  ```

**Troubleshooting:**
```bash
# If locked out, use VPS provider's web console, then:
ufw allow 22/tcp                  # Re-open SSH on all interfaces
systemctl restart ssh             # Restart sshd
fail2ban-client unban --all       # Unban all IPs

# Force re-run all chezmoi scripts
rm -rf ~/.cache/chezmoi-state
chezmoi apply --force

# Check what fail2ban has banned
fail2ban-client status sshd
```

## Version Control with Jujutsu (jj)

**IMPORTANT:** Always use `jj` instead of `git` for version control operations. Jujutsu is a Git-compatible VCS with enhanced features. See [official docs](https://docs.jj-vcs.dev/latest/cli-reference/).

### Key Concepts

- **Change ID**: Stable identifier (e.g., `kntqzsqt`) - survives rewrites
- **Commit ID**: Content hash (e.g., `5d39e19d`) - changes when amended
- **Working copy (`@`)**: Always a commit, auto-updated by jj
- **No staging area**: All file changes are automatically tracked
- **`@-`**: Parent of working copy

### Quick Reference

```bash
# Status & Inspection
jj status                    # Show working copy status
jj log                       # Show commit history graph
jj diff                      # Show changes in working copy
jj show                      # Show commit details

# Creating & Modifying Changes
jj new -m "feat: description"   # Create new change with message
jj new                          # Create empty change (scratch/index)
jj describe -m "message"        # Update current change description
jj edit <change-id>             # Resume editing a specific change
jj next --edit                  # Move to child change and edit

# Restructuring
jj squash                    # Move all changes to parent (like --amend)
jj squash -i                 # Interactive squash (select hunks)
jj split                     # Split change into multiple
jj abandon                   # Discard current change
jj rebase -s <src> -d <dst>  # Rebase changes

# Bookmarks (Branches)
jj bookmark create <name>    # Create bookmark at current change
jj bookmark move <name>      # Move bookmark to current change
jj bookmark list             # List all bookmarks
jj bookmark delete <name>    # Delete bookmark

# Git Integration
jj git fetch                 # Fetch from remote
jj git push                  # Push to remote
jj git push -b <bookmark>    # Push specific bookmark

# Undo/Redo
jj undo                      # Undo last operation
jj redo                      # Redo undone operation
jj op log                    # View operation history
```

### Workflow: Squash (use `@` like staging area)

Use when you want a clean commit with a scratch change on top:

```bash
jj describe -m "feat: implement X"  # Describe the real change
jj new                              # Create scratch change on top
# ... make edits ...
jj squash                           # Move changes from @ into @- (parent)
jj squash -i                        # Interactive: pick files/hunks
```

### Workflow: Edit (insert prerequisite change)

Use when you need a refactor before your current change:

```bash
jj new -m "feat: implement X"       # Start main change
jj new -B -m "refactor: prep work"  # Insert change BEFORE current (-B flag)
# ... do prerequisite work ...
jj next --edit                      # Return to original change
```

### Workflow: New Feature

```bash
jj new -m "feat: add feature X"
jj bookmark create feature-x
# ... make changes (auto-tracked) ...
jj status && jj diff                # Review
jj git push -b feature-x            # Push bookmark
```

### Workflow: Quick Fix

```bash
jj new -m "fix: correct typo"
# ... make fix ...
jj git push                         # Push directly
```

### Common Revsets

| Revset | Description |
|--------|-------------|
| `@` | Current working copy |
| `@-` | Parent of working copy |
| `@--` | Grandparent |
| `root()` | Root commit |
| `trunk()` | Main branch (main/master) |
| `bookmarks()` | All bookmarks |

### Commit Message Convention

Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance
