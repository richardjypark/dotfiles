---
name: dotfiles-version-refresh
description: "Update pinned tool versions and external dependency references for this chezmoi repo. Trigger when any tool, plugin, archive, or externals refresh behavior changes."
---

# Dotfiles Version Refresh

## When to use this skill

Use this skill when:

- bumping Node, NVM, Python, FZF, plugin, or archive revisions
- changing `.chezmoidata.toml`, `.chezmoiversion.toml`, or `.chezmoiexternal.toml.tmpl`
- adjusting setup logic because a pinned version or refresh policy changed

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `references/version-map.md`

## Workflow

1. Identify which dependency changes and load the file map in `references/version-map.md`.
2. Update all affected pin locations:
   - data/version files (`.chezmoidata.toml`, `.chezmoiversion.toml`)
   - external fetch definitions (`.chezmoiexternal.toml.tmpl`)
   - setup scripts that encode version behavior
3. Update docs when user-visible behavior or commands change:
   - `~/.local/share/chezmoi/README.md`
4. Preserve repo policy:
   - favor pinned, deterministic versions
   - keep `refreshPeriod` expectations aligned with current policy

## References

- `references/version-map.md` for the authoritative file map between pinned values, externals, scripts, and docs

## Stop and ask

- the desired outcome requires following an unpinned "latest" channel
- it is unclear which file should remain authoritative for a version value
- the refresh policy or user-facing maintenance commands would materially change

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
