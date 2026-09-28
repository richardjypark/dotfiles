# Version Map

Use this map to propagate version bumps safely.

## Pins That `chezmoi-bump` Owns

`chezmoi-bump --help` lists these dependencies. The tool updates their values in `.chezmoidata.toml` `[pinned.*]`, `.chezmoiversion.toml` `[versions]`, `.chezmoiexternal.toml.tmpl`, and the Pi package and settings files together. Use the tool; do not edit these values by hand.

## Pins That Need Manual Edits

- `.chezmoidata.toml`
  - `python.version`
  - `[pinned.go]`, with `.chezmoiversion.toml` `versions.go`
  - `[pinned.hermes_agent]` `version`, `ref`, `repo_url`, `branch`, and `extras`
- `.chezmoiexternal.toml.tmpl`
  - Oh My Zsh archive commit URL
- `private_dot_config/mise/modify_config.toml`
  - Global Node and package-manager defaults for managed agent tools.
  - Project-specific Erlang, Elixir, Node, and package-manager versions belong in each project's `mise.toml`.

## Script Touchpoints

- `.chezmoiscripts/run_onchange_after_20-setup-fzf.sh.tmpl`
  - Keep version extraction logic compatible with the external pin format.
- `.chezmoiscripts/run_after_30-setup-mise.sh.tmpl`
  - Keep global agent Node installation aligned with `private_dot_config/mise/modify_config.toml`.
- `.chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl`
  - Keep Python setup aligned with `.chezmoidata.toml`.
- `.chezmoiscripts/run_onchange_after_29-setup-ibkr-data-deps.sh.tmpl`
  - Keep managed Go setup aligned with `.chezmoidata.toml` `[pinned.go]`.
- `.chezmoiscripts/run_after_39-setup-hermes-agent.sh.tmpl` and `dot_local/private_lib/chezmoi/hermes/`
  - Keep the managed Hermes checkout, uv extras, local TUI patch sentinels, TUI prebuild, gateway service behavior, and public preference convergence aligned with `.chezmoidata.toml` `[pinned.hermes_agent]` and `[hermes.*]` data.

## Documentation Touchpoints

- `README.md`
  - Refresh installation, profile, and trust-flag guidance when behavior changes.

## Consistency Checks

1. The version appears in all required pin locations.
2. Rendered templates parse as valid shell/TOML.
3. `chezmoi apply --dry-run --refresh-externals` completes without template or fetch-configuration errors.
4. `chezmoi diff` shows only expected pin and documentation updates.
5. Hermes Agent bumps verify the resolved upstream commit, `pyproject.toml`/`hermes_cli.__version__`, local TUI patch sentinel lines, `hermes --version`, and a gateway service restart when enabled.
