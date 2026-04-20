# Autoresearch: health-check helper-command coverage cleanup

## Objective
Find and implement minimal, low-risk improvements so `chezmoi-health-check` verifies the repo's other documented managed helper commands too.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes aligned CI and health-check coverage for the four update wrappers; the next principled follow-through is to make sure the health-check command list also includes the repo's documented managed helpers `chezmoi-health-check` and `chezmoi-rerun-script`.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining managed-helper omissions in `chezmoi-health-check` for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `dot_local/bin/executable_chezmoi-health-check` for whether its managed-command loop still omits the documented helper commands `chezmoi-health-check` and `chezmoi-rerun-script`.

## Files in Scope
- `dot_local/bin/executable_chezmoi-health-check` — helper-command coverage should include the documented helper commands too
- `README.md` and `docs/tooling-and-skills.md` — source-of-truth docs already describing `chezmoi-health-check` and `chezmoi-rerun-script` as managed helpers

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
- The latest validation-symmetry passes aligned CI shell-parse coverage across `czu`, `czuf`, `czl`, and `czm`.
- Current plan: make the local health-check's managed-command loop match the documented helper set by adding `chezmoi-health-check` and `chezmoi-rerun-script`.
