# Autoresearch: Tailscale setup-template coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also renders and parses the Tailscale setup template.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, user-facing command entrypoints, and the remaining top-level local shell helpers. One concrete skill-guidance gap remains: `private_dot_agents/private_skills/chezmoi-script-maintainer/references/script-patterns.md` explicitly cites `.chezmoiscripts/run_onchange_after_37-setup-tailscale.sh.tmpl` as one of the canonical installer trust-gate examples, but the lightweight local autoresearch safety net still doesn't render-check it.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local Tailscale-template checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing Tailscale-template validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips rendering/parsing `.chezmoiscripts/run_onchange_after_37-setup-tailscale.sh.tmpl`.

## Files in Scope
- `autoresearch.checks.sh` — should render-check the Tailscale setup template too
- `.chezmoiscripts/run_onchange_after_37-setup-tailscale.sh.tmpl` — Tailscale setup template
- `private_dot_agents/private_skills/chezmoi-script-maintainer/references/script-patterns.md` — already cites this template as a canonical trust-gate example

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise `chezmoi execute-template ... | bash -n` check is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors most of those checks, including shell/tmux configs, bootstrap entrypoints, helper libraries, command entrypoints, render-safe managed targets, and the remaining top-level local shell helpers.
- Current plan: bring the Tailscale setup template into `autoresearch.checks.sh` so the script-maintainer skill's cited trust-gate example is covered locally too.
