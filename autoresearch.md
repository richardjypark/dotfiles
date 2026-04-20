# Autoresearch: maintenance-agent sibling entrypoint syntax coverage

## Objective
Find and implement a minimal, low-risk CI syntax-check coverage fix for the remaining unvalidated Pi maintenance-agent shell entrypoint.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes completed syntax coverage for the top-level `dot_local/bin/` shell entrypoints. One concrete integration gap remains: CI syntax-checks `run-maintenance.sh` but still skips its sibling `git-ssh.sh`, even though `run-maintenance.sh` references that helper directly.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining CI syntax omissions for the Pi maintenance-agent shell sibling entrypoints in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing CI validation coverage

## How to Run
`./autoresearch.sh`

The script audits the GitHub workflow syntax-check step for whether it still skips `dot_local/share/pi-maintenance-agent/bin/executable_git-ssh.sh` while already checking the sibling `executable_run-maintenance.sh`.

## Files in Scope
- `.github/workflows/managed-npm-safety.yml` — shell entrypoint syntax validation should include the sibling Pi maintenance-agent helper too
- `dot_local/share/pi-maintenance-agent/bin/executable_git-ssh.sh` — helper entrypoint currently skipped by CI syntax checks
- `dot_local/share/pi-maintenance-agent/bin/executable_run-maintenance.sh` — existing checked sibling that references `git-ssh.sh`

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
- The latest validation-symmetry passes completed CI shell syntax coverage for the top-level `dot_local/bin/` entrypoints and expanded local health-check command coverage.
- Current plan: add `git-ssh.sh` to the same CI shell syntax-check step that already validates `run-maintenance.sh`, since the latter directly uses the former.
