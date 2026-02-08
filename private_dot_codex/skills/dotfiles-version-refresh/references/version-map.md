# Version Map

Use this map to propagate version bumps safely.

## Primary Pin Files

- `.chezmoidata.toml`
  - `nvm.version`
  - `nvm.nodeVersion`
  - `python.version`
  - `npm.packages` (if package set changes with version policy)
- `.chezmoiversion.toml`
  - `versions.fzf`
- `.chezmoiexternal.toml.tmpl`
  - Oh My Zsh archive commit URL
  - zsh plugin release tarball URLs
  - fzf git branch/tag in `clone.args`
  - NVM archive URL (templated via `{{ .nvm.version }}`)

## Script Touchpoints

- `.chezmoiscripts/run_after_20-setup-fzf.sh`
  - Keep version extraction logic compatible with external pin format.
- `.chezmoiscripts/run_after_30-setup-node.sh.tmpl`
  - Keep Node/NVM setup logic aligned with `.chezmoidata.toml`.
- `.chezmoiscripts/run_after_25-setup-uv.sh.tmpl`
  - Keep Python setup aligned with `.chezmoidata.toml`.

## Documentation Touchpoints

- `README.md`
  - Refresh installation, profile, and trust-flag guidance when behavior changes.
- `CLAUDE.md`
  - Refresh pinned versions and setup-order notes when touched.

## Consistency Checks

1. Version appears in all required pin locations.
2. Rendered templates parse as valid shell/TOML.
3. `chezmoi apply --dry-run --refresh-externals` completes without template or fetch-configuration errors.
4. `chezmoi diff` shows only expected pin and documentation updates.
