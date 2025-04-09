# github.com/richardjypark/dotfiles

Richard Park's dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

Install them with:

    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b $HOME/.local/bin
    chezmoi init richardjypark
    chezmoi update
    exec zsh

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
- **Theme**: Spaceship Prompt
- **Zsh Plugins**:
  - zsh-syntax-highlighting
  - zsh-autosuggestions
  - fzf (fuzzy finder)
  - git
  - ssh-agent
- **Node.js Environment**:
  - nvm (Node Version Manager)
- **Terminal**: Ghostty
