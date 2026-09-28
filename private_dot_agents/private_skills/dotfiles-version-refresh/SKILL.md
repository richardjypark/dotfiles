---
name: dotfiles-version-refresh
description: "Update pinned tool versions and external dependency references for this chezmoi repo. Trigger when any tool, plugin, archive, or externals refresh behavior changes."
---

# Dotfiles Version Refresh

## When to use this skill

Use this skill when:

- checking which pinned tools are outdated
- bumping project runtimes, Python, Go, Hermes Agent, plugin, or archive revisions
- changing `.chezmoidata.toml`, `.chezmoiversion.toml`, or `.chezmoiexternal.toml.tmpl`
- adjusting setup logic because a pinned version or refresh policy changed

## Read first

- `~/.local/share/chezmoi/AGENTS.md`
- `~/.local/share/chezmoi/ARCHITECTURE.md`
- `references/version-map.md`

## Workflow

1. Check what is outdated with `chezmoi-bump --check` (or `czvc`). For the routine policy (stable releases at least seven days old), run `chezmoi-bump --automatic --all --check`.
2. For the dependencies that `chezmoi-bump --help` lists, use the tool. Do not edit their pins by hand. It updates every pin location and checksum, verifies the result, and rolls back on failure.
   - preview: `chezmoi-bump --dry-run <dep>`
   - apply: `chezmoi-bump <dep>` (or `czb <dep>`); `--all` bumps every outdated dependency
3. For other pins (Hermes Agent, Python, Go, Oh My Zsh, mise Node), edit every location in `references/version-map.md` by hand.
4. Update `README.md` when user-visible behavior or commands change.
5. Preserve repo policy: pinned, deterministic versions, and `refreshPeriod` values aligned with the current policy.

## Hermes Agent

- Pin `.chezmoidata.toml` `[pinned.hermes_agent]` to the resolved version and exact commit `ref`.
- If the user responds to Hermes' own "Update available" banner, run `hermes update`, pin the resulting upstream `main` commit, then verify that `hermes --version` reports `Up to date`.
- The setup script reverts its own TUI patches before it checks out a new ref, and it refuses to overwrite any other local change. If apply stops with "local changes exist", inspect `git -C ~/.local/share/hermes-agent diff` before you remove anything.
- After apply, `git -C ~/.local/share/hermes-agent status --short` must show only the managed TUI patch files.
- Restart `hermes-gateway.service` when the gateway marker is enabled so the always-on process uses the new checkout.

## References

- `references/version-map.md` for the pins that need manual edits and the scripts that read them

## Stop and ask

- the desired outcome requires following an unpinned "latest" channel
- it is unclear which file should remain authoritative for a version value
- the refresh policy or user-facing maintenance commands would materially change

## Validation

```bash
chezmoi execute-template < .chezmoiexternal.toml.tmpl | python3 -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
for f in .chezmoiscripts/*.tmpl; do chezmoi execute-template < "$f" | bash -n || echo "FAIL $f"; done
chezmoi apply --dry-run --refresh-externals
```

Run `chezmoi diff` before finishing to confirm only intended pin updates. For Hermes Agent bumps on an enabled host, also run `TRUST_ON_FIRST_USE_INSTALLERS=1 chezmoi apply`, `hermes --version`, and `chezmoi status --exclude scripts`.
