# Autoresearch: direct managed command coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the direct `chezmoi-bump` and `chezmoi-check-versions` managed command entrypoints under `dot_local/bin/`.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, and the user-facing wrapper commands (`czu`, `czuf`, `czl`, `czm`, `czb`, `czvc`, `chezmoi-rerun-script`). One adjacent user-facing gap remains: the repo also exposes direct managed commands `chezmoi-bump` and `chezmoi-check-versions`, CI already syntax-checks their source entrypoints, and the performance summary advertises them explicitly — but the lightweight local autoresearch safety net still doesn't.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local direct managed-command syntax checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing direct-command validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips local syntax checks for the direct managed command entrypoints.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the direct managed command entrypoints too
- `dot_local/bin/executable_chezmoi-bump` — source for the direct `chezmoi-bump` managed command
- `dot_local/bin/executable_chezmoi-check-versions` — source for the direct `chezmoi-check-versions` managed command
- `.chezmoiscripts/run_after_99-performance-summary.sh` and README command docs — already surface these commands as first-class maintenance helpers

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if concise `bash -n` checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors many of those high-impact checks, including shell/tmux configs, bootstrap entrypoints, helper libraries, wrapper commands, and render-safe managed targets.
- Current plan: mirror CI's direct syntax checks for the two remaining user-facing direct command entrypoints too, so local experiments touching those maintenance helpers inherit the same lightweight guardrails.
