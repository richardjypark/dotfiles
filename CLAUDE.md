# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a chezmoi-managed dotfiles repository optimized for performance with sophisticated state tracking and external resource management. The dotfiles configure Zsh with Oh My Zsh, Tmux with session persistence, and development tools (Node.js via NVM, Python via uv, fzf, Jujutsu, OpenCode, Claude Code, Tailscale).

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
- Oh My Zsh (archive from master)
- zsh-syntax-highlighting and zsh-autosuggestions (archives)
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
4. `run_after_20-setup-fzf.sh` - Install fzf from repository
5. `run_after_25-setup-uv.sh.tmpl` - Install Python uv package manager
6. `run_after_26-setup-jj.sh` - Install Jujutsu (jj) version control
7. `run_after_30-setup-node.sh.tmpl` - Set up Node.js via NVM
8. `run_after_30-change-shell.sh` - Change default shell to zsh
9. `run_after_35-setup-claude-code.sh` - Install Claude Code
10. `run_after_36-setup-opencode.sh` - Install OpenCode AI coding agent
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
- `~/.zshrc` - Interactive shells only (Oh My Zsh, plugins, aliases)
- `~/.config/shell/*.sh` - Modular configurations:
  - `path.sh` - PATH modifications
  - `alias.sh` - Custom aliases
  - `env.sh` - Environment variables
  - `history.sh` - History configuration
  - `fzf.sh` - fzf key bindings and completion
  - `zsh-fix.sh` - IFS fixes for Oh My Zsh compatibility
  - `agnoster-custom.sh` - Theme customizations
  - `gpg.sh` - GPG configuration

**ZSH Plugins (via Oh My Zsh):**
- git, terraform, ansible, ssh-agent, tmux, virtualenv
- zsh-autosuggestions, zsh-syntax-highlighting

## Tmux Configuration

**Key features:**
- Auto-start tmux (skipped for SSH sessions and VSCode)
- Session persistence via tmux-resurrect and tmux-continuum
- Auto-save every 15 minutes, auto-restore on start
- Vi mode keybindings, mouse support
- Status bar: red for SSH sessions, green for local

**Custom keybindings:**
- `Alt + h/j/k/l` - Navigate panes
- `Prefix + |` - Split vertically
- `Prefix + -` - Split horizontally
- `Prefix + Ctrl + s/r` - Manual save/restore

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
