# Chezmoi update helpers

# Compatibility: remove legacy aliases if they exist in current shell.
unalias czu 2>/dev/null || true
unalias czuf 2>/dev/null || true

# Update dotfiles and apply local changes.
czu() {
  command czu "$@"
}

# Force a full tool/external refresh and apply.
czuf() {
  command czuf "$@"
}
