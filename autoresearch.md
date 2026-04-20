# Autoresearch: shared helper-library syntax coverage in CI

## Objective
Find and implement minimal, low-risk CI syntax-check coverage fixes for the repo's shared shell helper libraries.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes expanded CI syntax coverage across the managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and broadened `autoresearch.checks.sh` across key rendered templates and the externals template. A remaining concrete gap is that the shared helper libraries those scripts source still are not syntax-checked directly in CI.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining CI syntax omissions for the shared helper libraries in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing CI validation coverage

## How to Run
`./autoresearch.sh`

The script audits the GitHub workflow syntax-check step for whether it still skips the shared helper libraries `scripts/lib/load-helpers.sh`, `dot_local/private_lib/chezmoi-helpers.sh`, and `dot_local/private_lib/chezmoi-update-helpers.sh`.

## Files in Scope
- `.github/workflows/managed-npm-safety.yml` — shell syntax validation should include the shared helper libraries too
- `scripts/lib/load-helpers.sh` — sourced by early bootstrap/prereq scripts
- `dot_local/private_lib/chezmoi-helpers.sh` — shared apply-time helper library
- `dot_local/private_lib/chezmoi-update-helpers.sh` — shared update-wrapper helper library

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the maintainer docs for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is docs-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise command reference is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- Recent helper-command discoverability/state-guidance passes surfaced `chezmoi-rerun-script` broadly, tightened `CLAUDE.md` so it now prefers targeted reruns over clearing all state, and cleaned up the remaining low-risk command-family symmetry gaps around `czm` in docs/comments.
- The latest validation-symmetry passes completed CI shell syntax coverage for the managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and broadened the local autoresearch safety net across the externals plus key setup templates.
- Current plan: add direct CI parse coverage for the shared helper libraries that many of those already-validated scripts source.
