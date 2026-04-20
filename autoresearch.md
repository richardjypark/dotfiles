# Autoresearch: remaining top-level bin entrypoint coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the final unmanaged top-level shell entrypoints under `dot_local/bin/`.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, the user-facing wrapper commands, the direct `chezmoi-bump` / `chezmoi-check-versions` entrypoints, and the Pi maintenance-agent shell pair. One bounded local/CI symmetry gap remains: CI still syntax-checks two top-level bin entrypoints that the local autoresearch safety net skips — `executable_omarchy-screenshot-active-window-clipboard` and `executable_tmux-status-host`. This is still principled rather than generic coverage hunting because they are the final top-level shell entrypoints left outside the local safety net, and at least one (`omarchy-screenshot-active-window-clipboard`) is wired into the managed Hypr bindings.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining top-level `dot_local/bin` shell entrypoints that local checks still skip in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing top-level bin validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips the remaining top-level `dot_local/bin` shell entrypoints.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the remaining top-level bin entrypoints too
- `dot_local/bin/executable_omarchy-screenshot-active-window-clipboard` — managed Omarchy screenshot helper referenced by Hypr bindings
- `dot_local/bin/executable_tmux-status-host` — remaining top-level tmux-related shell helper under local bin
- `.github/workflows/managed-npm-safety.yml` and `private_dot_config/hypr/bindings.conf` — establish these files as maintained integration surfaces

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Match each script's actual shell (`bash -n` for the screenshot helper, `sh -n` for the tmux status helper).
- Do not add vague prose if concise syntax checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors most of those checks, including shell/tmux configs, bootstrap entrypoints, helper libraries, wrapper commands, direct managed commands, and maintenance-agent entrypoints.
- Current plan: finish the local top-level-bin symmetry pass by adding the last two CI-covered shell entrypoints to `autoresearch.checks.sh`.
