# Autoresearch: repo-local Claude command cleanup

## Objective
Find and implement minimal, low-risk improvements to the tracked repo-local Claude command permission surface.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, and the latest segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts. Recent permission-cleanup passes also removed the easiest stale repo-local Claude Bash rules plus one stale explicit fetch domain. The next promising path is another agent-workflow cleanup: `.claude/settings.local.json` still allows `Bash(chmod:*)`, but exact hits are mostly user bootstrap examples and script implementation details rather than an explicit agent workflow that needs `chmod` pre-approved.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the repo-local Claude command-permission invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits `.claude/settings.local.json` and `dot_local/bin/executable_chezmoi-health-check` for one evidence-backed stale command permission and its matching drift warning.

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
- Recent segments removed stale `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, `Bash(cat:*)`, `Bash(alias:*)`, and `Bash(czu:*)` access from the tracked allowlist, each with a matching health-check warning.
- A recent segment also removed the stale explicit Influx WebFetch domain from the tracked allowlist, again with a matching health-check warning.
- Remaining Bash permissions are harder to trim, but `chmod` currently looks like the next best candidate: exact hits are confined to user bootstrap snippets plus implementation details, not the repo's agent-facing first-pass or validation workflows.
- Current plan: remove `Bash(chmod:*)` from `.claude/settings.local.json` and add a matching health-check warning so bootstrap-style permission tweaks do not stay pre-approved without an explicit agent-workflow need.
