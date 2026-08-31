# Architecture And Performance

## Layout

- Source of truth: `~/.local/share/chezmoi`
- Render target: `~/`
- `dot_*` -> `.*`
- `private_*` -> restricted permissions
- `*.tmpl` -> rendered with `.chezmoidata.toml`

## Script Contract

All setup scripts in `.chezmoiscripts/` should:

1. source `~/.local/lib/chezmoi-helpers.sh`
2. be idempotent
3. be quiet by default (`vecho` vs `eecho`)
4. use state markers in `~/.cache/chezmoi-state`
5. gate remote installer/download behavior behind `TRUST_ON_FIRST_USE_INSTALLERS=1`

## Shared Helpers

Primary helper file: `dot_local/private_lib/chezmoi-helpers.sh`

Key capabilities:

- logging helpers (`vecho`, `eecho`)
- state helpers (`state_exists`, `mark_state`, `clear_state`)
- targeted rerun helper (`chezmoi-rerun-script <source-script-path>`) for clearing one remembered `run_onchange_*` state entry without wiping the whole state directory
- privilege helpers (`ensure_sudo`, `run_privileged`)
- trust gates (`require_trust_for_remote_installer`, `require_trust_for_remote_download`)
- platform detection (`detect_platform`, `platform_key`)
- cached verified downloads (`download_and_verify`)

## Performance Model

Fast subsequent runs rely on:

- state-file short-circuiting
- pinned artifacts with checksum verification
- local download cache reuse (`~/.cache/chezmoi-downloads`)
- optional parallel prefetch (`run_onchange_before_02-prefetch-assets.sh.tmpl`)

Tuning note:

- `CHEZMOI_PREFETCH_JOBS` defaults to `4`; use roughly `min(cores, 8)` on modern machines to balance throughput and API/network pressure.

## Validation Checklist

Use focused tests while editing. Before completing a task, run the aggregate non-mutating check:

```bash
./tests/all
```

The local command does not install packages or use the network. It reports managed npm suites as skipped when their dependencies are absent. Skipped suites are not passes and must be included in the result summary. CI installs the committed npm dependencies and uses required mode:

```bash
REQUIRE_MANAGED_NPM_TESTS=1 ./tests/all
```

At an approved apply gate, verify rendered targets:

```bash
chezmoi diff
chezmoi apply
chezmoi status
```
