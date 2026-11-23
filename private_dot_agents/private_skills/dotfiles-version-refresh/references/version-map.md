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
  - `anatomy` skill archive commit URL (wheresryan22/anatomy release commit). Review the upstream diff for new network calls, scripts, and publish behavior before you bump it. The v1.1.0 pin was added on 2026-10-12, before the seven-day age, as an approved exception.
  - `modern-web-guidance` npm tarball URL and `checksum.sha256` (GoogleChrome). Diff the upstream `SKILL.md` and CLI first. Bump the tarball version, the checksum, and `npm-version` in `private_dot_agents/private_skills/modern-web-guidance/SKILL.md` together; `tests/test_agent_instructions.py` fails when they disagree. The 1.0.0 pin was added on 2026-11-14, before the seven-day age, as a reviewed exception.
- `private_dot_config/mise/modify_config.toml`
  - Global Node and package-manager defaults for managed agent tools.
  - Project-specific Erlang, Elixir, Node, and package-manager versions belong in each project's `mise.toml`.
- `.github/workflows/*.yml`
  - `go-version` follows the `[pinned.go]` minor line, and `node-version` follows the mise Node pin. `tests/test_ci_versions.py` checks both.
  - PyYAML in `managed-npm-safety.yml` has no updater. Bump `PYYAML_VERSION` and `PYYAML_SHA256` together; take the sdist SHA256 from the PyPI JSON API (`https://pypi.org/pypi/PyYAML/<version>/json`).
- `.github/tools/shell-test-debs.sha256`
  - The zsh, zsh-common, and ripgrep packages for the Linux CI job (Ubuntu 24.04, amd64), as `<sha256>  <file>` lines. Take each hash from the signed index with `apt-cache show <package>=<version>` on Ubuntu 24.04 amd64. A changed list changes the cache key, so the next run downloads and checks the new files.
- `dot_local/bin/executable_dotfiles-secret-scan`
  - The local gitleaks default. Set it to the `.github/tools/go.mod` version when you merge a gitleaks update.

## Pins That Dependabot Owns

`.github/dependabot.yml` proposes these updates as PRs: GitHub Actions, the OpenRouter agent npm packages, and the CI tools gitleaks and actionlint in `.github/tools/go.mod`. `.github/tools/tools.go` keeps the CI tools direct requirements, because Dependabot does not update Go tool directives.

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
- `private_dot_agents/private_skills/socratic-tutor/` and other skills from `janestreet/agent_skills`
  - Do not edit by hand. Review the upstream diff, then run `python3 scripts/sync-upstream-skills.py`. It updates `metadata.upstream.commit` and every file in the folder. The daily `upstream-skills` workflow opens an issue when upstream changes.

## Documentation Touchpoints

- `README.md`
  - Refresh installation, profile, and trust-flag guidance when behavior changes.

## Consistency Checks

1. The version appears in all required pin locations.
2. Rendered templates parse as valid shell/TOML.
3. `chezmoi apply --dry-run --refresh-externals` completes without template or fetch-configuration errors.
4. `chezmoi diff` shows only expected pin and documentation updates.
5. Hermes Agent bumps verify the resolved upstream commit, `pyproject.toml`/`hermes_cli.__version__`, local TUI patch sentinel lines, `hermes --version`, and a gateway service restart when enabled.
