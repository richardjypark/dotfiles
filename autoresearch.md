# Autoresearch: repo-local Claude command cleanup

## Objective
Find and implement minimal, low-risk improvements to the tracked repo-local Claude command permission surface.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, and the latest segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts. Recent permission-cleanup passes also removed the easiest stale repo-local Claude Bash rules plus one stale explicit fetch domain. The next promising path is a convenience-command cleanup: `.claude/settings.local.json` still allows `Bash(czu:*)`, but `czu` is primarily documented as a user-facing wrapper, while agent guidance already points to the underlying `jj` and `chezmoi` workflows.

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
- Recent segments removed stale `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, `Bash(cat:*)`, and `Bash(alias:*)` access from the tracked allowlist, each with a matching health-check warning.
- A recent segment also removed the stale explicit Influx WebFetch domain from the tracked allowlist, again with a matching health-check warning.
- Remaining Bash permissions are harder to trim, but `czu` stands out as a user-facing wrapper rather than a core agent workflow primitive: repo docs describe it as a convenience command, while agent-facing guidance still points to direct `jj` / `chezmoi` operations.
- Current plan: remove `Bash(czu:*)` from `.claude/settings.local.json` and add a matching health-check warning so convenience wrappers do not stay pre-approved without an explicit agent-workflow need.
