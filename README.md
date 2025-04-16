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
  - terraform
- **Node.js Environment**:
  - nvm (Node Version Manager)
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
