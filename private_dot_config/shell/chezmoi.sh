# Chezmoi update helpers

chezmoi_source_dir() {
  printf '%s\n' "$HOME/.local/share/chezmoi"
}

chezmoi_prepare_jj_update() {
  local repo
  repo="$(chezmoi_source_dir)"
  jj -R "$repo" git fetch
  jj -R "$repo" rebase -d master
}

# Update dotfiles and apply local changes.
czu() {
  chezmoi_prepare_jj_update && chezmoi apply
}

# Force a full tool/external refresh and apply.
czuf() {
  chezmoi_prepare_jj_update && TRUST_ON_FIRST_USE_INSTALLERS=1 CHEZMOI_FORCE_UPDATE=1 chezmoi apply --refresh-externals --force
}
