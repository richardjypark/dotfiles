# Autoresearch: managed agent settings coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` also validates the repo-managed Claude and Pi settings JSON files.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, `.chezmoiexternal.toml.tmpl`, and the authoritative version-data TOML files. One adjacent agent-config gap remains: the lightweight safety net still parses repo-local Claude policy JSON and rendered Codex TOML, but it does not parse the managed source settings at `private_dot_claude/settings.json` and `dot_pi/agent/settings.json`, and it does not dry-run their rendered targets under `~/.claude/` and `~/.pi/agent/`.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the managed Claude/Pi settings files in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips parsing the managed Claude/Pi settings JSON sources or dry-running their rendered targets.

## Files in Scope
- `autoresearch.checks.sh` — should validate the managed Claude/Pi settings too
- `private_dot_claude/settings.json` — managed Claude global settings source
- `dot_pi/agent/settings.json` — managed Pi settings source
- `AGENTS.md`, `ARCHITECTURE.md`, and README Pi-maintenance guidance — these settings are tracked agent-config surfaces with real runtime impact

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise parse/dry-run check is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, and broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources.
- Current plan: add managed Claude/Pi settings parse and dry-run coverage so routine experiments inherit basic validation for those tracked agent-config surfaces too.
