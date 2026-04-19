# Autoresearch: Claude allowlist policy wording alignment

## Objective
Find and implement minimal, low-risk improvements to how this repo documents the tracked project-local Claude allowlist policy.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, and recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain. The next promising path is to codify the policy that emerged from those cleanups: tracked repo-local Claude permissions should stay limited to core workflow primitives, while convenience/bootstrap/one-off commands should rely on explicit approval.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the repo-local Claude allowlist-policy wording invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the canonical Claude-facing docs for an explicit statement that tracked repo-local permissions are for core workflow primitives and that one-off convenience commands should prompt instead of being pre-approved.

## Files in Scope
- `CLAUDE.md` — Claude-facing repo workflow and policy doc
- `docs/tooling-and-skills.md` — canonical cross-tool agent tooling/policy doc

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
- Recent segments removed stale `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, `Bash(cat:*)`, `Bash(alias:*)`, `Bash(czu:*)`, `Bash(chmod:*)`, `Bash(mkdir:*)`, and `Bash(source:*)` access from the tracked allowlist, each with a matching health-check warning.
- A recent segment also removed the stale explicit Influx WebFetch domain from the tracked allowlist, again with a matching health-check warning.
- Those changes established a clearer repo policy, but the docs still only say the allowlist should stay “narrow and domain-scoped”. They do not yet say the more actionable rule that emerged from the cleanup work: reserve tracked permissions for core workflow primitives and let one-off convenience/bootstrap commands prompt.
- Current plan: add that policy sentence to `CLAUDE.md` and `docs/tooling-and-skills.md` so future changes have a clearer source of truth than grep-based archaeology.
