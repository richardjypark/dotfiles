# Autoresearch: documented managed-command entrypoint coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the documented managed helper/wrapper commands under `dot_local/bin/`.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, and the shared helper libraries. One concrete user-facing gap remains: README and the tooling docs present `czu`, `czuf`, `czl`, `czm`, `czb`, `czvc`, and `chezmoi-rerun-script` as first-class managed commands in `~/.local/bin`, and CI already syntax-checks their source entrypoints — but the lightweight local autoresearch safety net still doesn't.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local managed-command syntax checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing managed-command validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips local syntax checks for the documented managed helper/wrapper commands.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the documented managed command entrypoints too
- `dot_local/bin/executable_czu`, `executable_czuf`, `executable_czl`, `executable_czm`, `executable_czb`, `executable_czvc` — documented maintenance wrappers
- `dot_local/bin/executable_chezmoi-rerun-script` — documented recovery helper
- README and docs/tooling-and-skills.md — already document these commands as managed first-class entrypoints

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
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors many of those high-impact checks, including shell/tmux configs, bootstrap entrypoints, and helper libraries.
- Current plan: mirror CI's direct syntax checks for the documented maintenance/recovery command entrypoints too, so local experiments touching those user-facing wrappers inherit the same lightweight guardrails.
