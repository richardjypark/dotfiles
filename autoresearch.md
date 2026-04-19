# Autoresearch: repo-local Claude permission cleanup

## Objective
Find and implement minimal, low-risk improvements to the tracked repo-local Claude permission surface.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, and the latest segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts. The next promising path returns to repo-local Claude permission tightening. After removing `WebFetch(domain:*)` and `Bash(dscl:*)`, one suspicious leftover allow rule remains: `Bash(tree:*)` still exists in `.claude/settings.local.json`, but the repo's docs, skills, and scripts do not appear to use the `tree` command as part of any documented workflow.

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
- Current evidence: `Bash(tree:*)` remains in `.claude/settings.local.json`, but exact-command searches across the repo's docs, skills, scripts, and shell config do not show `tree` as a documented or implemented workflow command. This makes it look more like stale permission debt than an intentional repo requirement.
- Current plan: remove `Bash(tree:*)` from the tracked allowlist and add a matching health-check warning so the permission does not silently return.
