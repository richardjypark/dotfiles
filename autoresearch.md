# Autoresearch: targeted rerun-helper discoverability in maintainer docs

## Objective
Find and implement minimal, low-risk improvements to discoverability for the managed `chezmoi-rerun-script` helper in maintainer-facing architecture and script docs.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and recent helper-command discoverability cleanups surfaced `chezmoi-rerun-script` in README, `CLAUDE.md`, `docs/tooling-and-skills.md`, and the always-run performance summary. The next promising low-risk path is to surface that same helper in the maintainer docs that currently discuss raw state markers without mentioning the sanctioned one-script rerun command.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing maintainer-doc references to the managed `chezmoi-rerun-script` helper.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing maintainer-guidance references

## How to Run
`./autoresearch.sh`

The script audits maintainer-facing docs that already talk about `.chezmoiscripts/*` state markers to make sure they also mention the managed `chezmoi-rerun-script` recovery helper.

## Files in Scope
- `ARCHITECTURE.md` — maintainer-facing architecture doc that mentions state markers
- `docs/architecture-and-performance.md` — maintainer-facing script contract/performance doc
- `private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md` — script-maintainer workflow doc
- `README.md`, `CLAUDE.md`, and `docs/tooling-and-skills.md` — existing source-of-truth docs that already mention `chezmoi-rerun-script`

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
- Recent helper-command discoverability passes surfaced `chezmoi-rerun-script` in README, `CLAUDE.md`, `docs/tooling-and-skills.md`, and the always-run performance summary.
- The remaining low-risk gap is narrower: maintainer docs still talk about raw state markers without pointing to the sanctioned helper that clears one script's remembered `run_onchange_*` state.
- Current plan: add concise `chezmoi-rerun-script` references where maintainers learn about script state tracking.
