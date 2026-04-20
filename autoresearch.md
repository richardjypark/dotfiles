# Autoresearch: Pi maintenance-agent helper coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the Pi maintenance agent shell entrypoints.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, wrapper commands, and the direct `chezmoi-bump` / `chezmoi-check-versions` entrypoints. One concrete integration gap remains: CI already syntax-checks the Pi maintenance agent's `bin/run-maintenance.sh` and its referenced `bin/git-ssh.sh` helper, `dot_local/share/pi-maintenance-agent/README.md` documents `bin/run-maintenance.sh` as the main scheduled entrypoint, and the run-maintenance script explicitly wires in the git-ssh helper — but the lightweight local autoresearch safety net still doesn't check either file.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local Pi maintenance-agent shell entrypoint checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing maintenance-agent validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips local syntax checks for the Pi maintenance agent shell entrypoints.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the maintenance-agent entrypoints too
- `dot_local/share/pi-maintenance-agent/bin/executable_run-maintenance.sh` — main scheduled maintenance entrypoint
- `dot_local/share/pi-maintenance-agent/bin/executable_git-ssh.sh` — helper invoked by `run-maintenance.sh` via `GIT_SSH_COMMAND`
- `dot_local/share/pi-maintenance-agent/README.md` and CI shell checks — already establish these paths as maintained integration surfaces

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
- Current plan: mirror CI's direct syntax checks for the maintenance-agent entrypoint pair so local experiments touching the scheduled maintenance flow inherit the same lightweight guardrails.
