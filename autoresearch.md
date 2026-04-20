# Autoresearch: prerequisite template parse coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` parses the repo's high-impact prerequisites template too.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes expanded CI syntax coverage across the managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts. One local validation gap remains: `autoresearch.checks.sh` still doesn't template-parse the high-impact `run_onchange_before_00-prerequisites.sh.tmpl` script that maintainer docs explicitly call out.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the documented high-impact prerequisites template in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips `chezmoi execute-template < .chezmoiscripts/run_onchange_before_00-prerequisites.sh.tmpl | bash -n`.

## Files in Scope
- `autoresearch.checks.sh` — should template-parse the documented prerequisites script too
- `.chezmoiscripts/run_onchange_before_00-prerequisites.sh.tmpl` — high-impact prerequisites template
- `docs/architecture-and-performance.md` — already calls out this template in the validation checklist

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
- The latest validation-symmetry passes completed CI shell syntax coverage for the top-level managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and expanded local health-check command coverage.
- Current plan: make `autoresearch.checks.sh` cover the high-impact prerequisites template that maintainer docs already single out in the validation checklist.
