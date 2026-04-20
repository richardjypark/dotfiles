# Autoresearch: update-wrapper CI syntax coverage cleanup

## Objective
Find and implement minimal, low-risk CI syntax-check coverage fixes for the remaining managed update wrappers `czu` and `czuf`.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest segment brought `czm` into the same health-check and CI syntax coverage as `czl`; the next principled follow-through is to make sure the two base update wrappers `czu` and `czuf` also get explicit CI shell-parse coverage.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining CI syntax-coverage omissions for `czu`/`czuf` in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing CI validation coverage

## How to Run
`./autoresearch.sh`

The script audits the GitHub workflow syntax-check step for whether it still skips `dot_local/bin/executable_czu` and `dot_local/bin/executable_czuf`.

## Files in Scope
- `.github/workflows/managed-npm-safety.yml` — shell entrypoint syntax validation should include `dot_local/bin/executable_czu` and `dot_local/bin/executable_czuf`
- `dot_local/bin/executable_czu` — base jj/chezmoi update wrapper
- `dot_local/bin/executable_czuf` — forced refresh/update wrapper

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
- The latest validation-symmetry pass brought `czm` into the managed helper audit and CI shell-entrypoint syntax checks.
- Current plan: extend that same CI shell-parse coverage to the base update wrappers `czu` and `czuf`, which are also first-class managed entrypoints.
