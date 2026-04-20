# Autoresearch: managed helper CI syntax coverage cleanup

## Objective
Find and implement minimal, low-risk CI syntax-check coverage fixes for the remaining documented managed helper commands under `dot_local/bin/`.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes aligned CI shell-parse coverage for the four update wrappers and brought `chezmoi-rerun-script` into the local health-check. A remaining principled path is to give the rest of the documented managed helper commands explicit CI syntax coverage too.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining documented managed-helper CI syntax omissions in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing CI validation coverage

## How to Run
`./autoresearch.sh`

The script audits the GitHub workflow syntax-check step for whether it still skips the documented managed helper commands `czb`, `czvc`, `chezmoi-health-check`, `chezmoi-rerun-script`, `chezmoi-bump`, and `chezmoi-check-versions`.

## Files in Scope
- `.github/workflows/managed-npm-safety.yml` — shell entrypoint syntax validation should include the remaining documented managed helper commands
- `dot_local/bin/executable_czb`
- `dot_local/bin/executable_czvc`
- `dot_local/bin/executable_chezmoi-health-check`
- `dot_local/bin/executable_chezmoi-rerun-script`
- `dot_local/bin/executable_chezmoi-bump`
- `dot_local/bin/executable_chezmoi-check-versions`

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
- The latest validation-symmetry passes aligned CI shell-parse coverage across `czu`, `czuf`, `czl`, and `czm`, and added `chezmoi-rerun-script` to the local health-check loop.
- Current plan: extend CI shell syntax coverage to the remaining documented managed helper commands under `dot_local/bin/`.
