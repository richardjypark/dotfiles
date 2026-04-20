# Autoresearch: update-helper shared-library comment symmetry cleanup

## Objective
Find and implement a minimal, low-risk consistency fix in `dot_local/private_lib/chezmoi-update-helpers.sh` so its header comment includes the macOS maintenance wrapper `czm` alongside the other helper scripts that source it.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the helper-command discoverability/state-guidance cleanup is now largely spent down. After fixing the bootstrap doc intro, one similar comment-level symmetry gap remains: the shared update-helper library still says it is only for `czu`/`czuf`/`czl` even though `czm` also sources it.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of shared-library header omissions for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — stale or misleading comment wording

## How to Run
`./autoresearch.sh`

The script audits `dot_local/private_lib/chezmoi-update-helpers.sh` for whether its header comment still omits `czm` even though the macOS wrapper sources the file.

## Files in Scope
- `dot_local/private_lib/chezmoi-update-helpers.sh` — header comment still omits `czm`
- `dot_local/bin/executable_czm` — current source of truth confirming `czm` sources the shared helper library

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
- Recent helper-command discoverability/state-guidance passes surfaced `chezmoi-rerun-script` broadly and tightened `CLAUDE.md` so it now prefers targeted reruns over clearing all state.
- The larger stale doc/reference cleanup for `run_onchange_*` paths is now effectively complete, including the last targeted source comment.
- After the bootstrap doc intro fix, one similar symmetry gap remains in the shared update-helper library header: `czm` uses the file but is not named in the comment.
- Current plan: update the helper-library header comment so it accurately lists all wrapper scripts that source it.
