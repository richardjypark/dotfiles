---
name: dotfiles-version-refresh
description: "Update pinned tool versions and external dependency references for this chezmoi repo. Use when bumping Node/NVM/Python/FZF or plugin/archive revisions across `.chezmoidata.toml`, `.chezmoiversion.toml`, `.chezmoiexternal.toml.tmpl`, and related setup scripts and docs."
---

# Dotfiles Version Refresh

Use this skill to keep version pins and external fetches consistent across templates, scripts, and docs.

## Workflow

1. Identify which dependency changes and load the file map in `references/version-map.md`.

2. Update all affected pin locations:
- Data/version files (`.chezmoidata.toml`, `.chezmoiversion.toml`).
- External fetch definitions (`.chezmoiexternal.toml.tmpl`).
- Setup scripts that encode version behavior.

3. Update docs when user-visible behavior or commands change:
- `README.md`
- `CLAUDE.md`

4. Preserve repo policy:
- Favor pinned, deterministic versions.
- Keep `refreshPeriod` expectations aligned with current policy.

## Validation

Use template rendering + shell parsing for `.tmpl` files:

```bash
chezmoi execute-template < .chezmoiexternal.toml.tmpl >/tmp/chezmoiexternal.rendered.toml
chezmoi execute-template < .chezmoiscripts/run_after_30-setup-node.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_after_25-setup-uv.sh.tmpl | bash -n
bash -n .chezmoiscripts/run_after_20-setup-fzf.sh
chezmoi apply --dry-run --refresh-externals
```

Run `chezmoi diff` before finishing to confirm only intended pin updates.
