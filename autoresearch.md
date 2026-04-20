# Autoresearch: czm validation symmetry cleanup

## Objective
Find and implement minimal, low-risk validation-symmetry fixes so the macOS maintenance wrapper `czm` is checked anywhere the repo already treats sibling managed wrappers as first-class entrypoints.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. A remaining principled path is validation symmetry: `czm` is now documented everywhere as a first-class managed wrapper, so health checks and CI syntax checks should not silently skip it while still checking sibling wrappers.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining `czm` validation-symmetry omissions for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check or CI validation coverage

## How to Run
`./autoresearch.sh`

The script audits the repo's lightweight validation surfaces for whether they still skip `czm` while already validating sibling managed wrappers.

## Files in Scope
- `dot_local/bin/executable_chezmoi-health-check` — helper-command presence checks should include `czm`
- `.github/workflows/managed-npm-safety.yml` — shell entrypoint syntax validation should include `dot_local/bin/executable_czm`
- `dot_local/bin/executable_czm` — target entrypoint whose existence justifies the added checks

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
- The next low-risk path is no longer more prose; it is making sure lightweight validation surfaces treat `czm` like the other managed wrappers they already mention or syntax-check.
- Current plan: add `czm` to the managed helper command checks in `chezmoi-health-check` and to the CI shell-entrypoint syntax validation list if the audit confirms both omissions.
