# Autoresearch: maintenance-doc consistency cleanup

## Objective
Find and implement minimal, low-risk improvements to consistency across the user-facing maintenance docs.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the deferred Neovim semantics note was clarified inline. The next promising path is a small docs consistency cleanup: `docs/bootstrap-and-flags.md` still says `czl` updates the globally installed Pi Coding Agent via npm, but the canonical README and tooling docs now say Pi updates are handled by the repo's managed pinned install during apply.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the maintenance-doc consistency invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the maintenance docs for stale `czl` wording that still implies floating global npm-based Pi updates.

## Files in Scope
- `docs/bootstrap-and-flags.md` — maintenance/flag reference with the stale `czl` wording
- `README.md` — canonical current wording for `czl`
- `docs/tooling-and-skills.md` — canonical current tooling wording for `czl`

## Off Limits
- Benchmark cheating: do not remove audit checks unless a stronger equivalent guarantee replaces them.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve secure defaults.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the audit by weakening it; improve the repo for principled reasons.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog: tracked Claude defaults are safer, docs and health checks are aligned, and Codex skill metadata now front-loads the key jj/read-first cues.
- Recent segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts.
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, improved the two remaining always-run warm paths, and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- The older dispatcher/consolidation performance idea now looks mostly stale because only two always-run scripts remain and both already received their low-hanging warm-path cleanups.
- Kept in the latest segment: the Neovim setup script now explicitly states that `REQUIRED_NVIM_VERSION` is the compatibility floor while `PINNED_NVIM_VERSION` is only the preferred install source.
- New low-hanging doc gap: `docs/bootstrap-and-flags.md` still describes `czl` as updating the Pi Coding Agent via global npm, which is now inconsistent with `README.md` and `docs/tooling-and-skills.md` after the pinned-install policy change.
- Current plan: align `docs/bootstrap-and-flags.md` with the canonical current wording so all maintenance docs describe `czl` the same way.
