---
name: dotfiles-version-refresh
description: "Update pinned tool versions and external dependency references for this chezmoi repo. Trigger when any tool, plugin, archive, or externals refresh behavior changes."
---

# Dotfiles Version Refresh

## When to use this skill

Use this skill when:

- bumping Node, NVM, Python, FZF, Hermes Agent, plugin, or archive revisions
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
5. For Hermes Agent, keep "latest" deterministic:
   - update `.chezmoidata.toml` `[pinned.hermes_agent]` to the resolved version and exact commit ref
   - if the user is responding to Hermes' own "Update available" banner, pin the current upstream `main` commit rather than leaving the checkout on an older release/tag commit, then verify `hermes --version` reports `Up to date`
   - restart `hermes-gateway.service` when the gateway marker is enabled so the always-on process uses the new checkout

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
chezmoi execute-template < .chezmoiscripts/run_onchange_after_30-setup-node.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_onchange_after_20-setup-fzf.sh.tmpl | bash -n
chezmoi execute-template < .chezmoiscripts/run_after_39-setup-hermes-agent.sh.tmpl | bash -n
chezmoi apply --dry-run --refresh-externals
```

Run `chezmoi diff` before finishing to confirm only intended pin updates. For Hermes Agent bumps on an enabled host, also run `TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply`, `hermes --version`, and `chezmoi status --exclude scripts`.
