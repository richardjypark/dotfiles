# Autoresearch: repo-local Claude permission cleanup

## Objective
Find and implement minimal, low-risk improvements to the tracked repo-local Claude permission surface.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, and the latest segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts. The current path continues repo-local Claude permission tightening. After removing `WebFetch(domain:*)`, `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, and `Bash(cat:*)`, the next suspicious leftover allow rule is `Bash(alias:*)`: exact-command searches only find noun-style documentation references plus shell-config implementation uses, not a documented agent workflow that needs the `alias` builtin pre-approved.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the repo-local Claude permission invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits `.claude/settings.local.json` and `dot_local/bin/executable_chezmoi-health-check` for one evidence-backed stale permission and its matching drift warning.

## Files in Scope
- `.claude/settings.local.json` — tracked repo-local Claude allowlist
- `dot_local/bin/executable_chezmoi-health-check` — drift warning surface for repo-local Claude permissions

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
- Recent segments removed stale `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, and `Bash(cat:*)` access from the tracked allowlist, each with a matching health-check warning.
- Current evidence: `Bash(alias:*)` remains in `.claude/settings.local.json`, but exact-command searches only find noun-style documentation references and shell-config implementation lines, not an explicit workflow telling agents to run the `alias` builtin.
- Current plan: remove `Bash(alias:*)` from the tracked allowlist and add a matching health-check warning so the permission does not silently return.
