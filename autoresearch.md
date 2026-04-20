# Autoresearch: shared helper-library coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the shared helper libraries that many apply-time scripts depend on.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, and documented bootstrap/hardening entrypoints. One concrete high-leverage gap remains: the repo's apply-time scripts depend on `dot_local/private_lib/chezmoi-helpers.sh` and related loaders/helpers, `ARCHITECTURE.md` explicitly calls `dot_local/private_lib/chezmoi-helpers.sh` the shared contract for setup scripts, and CI already syntax-checks the helper libraries directly — but the lightweight local autoresearch safety net still doesn't.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local shared-helper syntax checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing shared-helper validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips local syntax checks for the shared helper libraries.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the shared helper libraries too
- `scripts/lib/load-helpers.sh` — shared loader used by setup scripts
- `dot_local/private_lib/chezmoi-helpers.sh` — shared helper contract for apply-time scripts
- `dot_local/private_lib/chezmoi-update-helpers.sh` — shared update helper library
- `AGENTS.md`, `ARCHITECTURE.md`, README, and `chezmoi-script-maintainer` guidance — already describe the repo's helper-driven script model

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if concise `bash -n` checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, added managed Claude/Pi settings plus agent-tool setup-template coverage, replaced the remaining `apply --dry-run` target checks with render-safe validation, aligned the local safety net with the documented shell/tmux checks, and then added the documented bootstrap entrypoints locally too.
- Current plan: mirror CI's direct helper-library syntax checks locally so autoresearch catches shared helper regressions at the source rather than only via selected caller scripts.
