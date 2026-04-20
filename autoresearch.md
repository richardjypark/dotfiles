# Autoresearch: prefetch-assets template coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also renders and parses the optional prefetch-assets template.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, user-facing command entrypoints, maintenance-agent shell entrypoints, and the Tailscale setup template. One concrete docs-driven gap remains: `docs/architecture-and-performance.md` explicitly calls out `run_onchange_before_02-prefetch-assets.sh.tmpl` as the optional parallel prefetch path, but the lightweight local autoresearch safety net still doesn't render-check it.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local prefetch-template checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing prefetch-template validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips rendering/parsing `.chezmoiscripts/run_onchange_before_02-prefetch-assets.sh.tmpl`.

## Files in Scope
- `autoresearch.checks.sh` — should render-check the prefetch-assets template too
- `.chezmoiscripts/run_onchange_before_02-prefetch-assets.sh.tmpl` — optional parallel prefetch template
- `docs/architecture-and-performance.md` — already documents this script as part of the repo's performance architecture

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
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors most of those checks, including shell/tmux configs, bootstrap entrypoints, helper libraries, command entrypoints, render-safe managed targets, maintenance-agent entrypoints, and the Tailscale installer trust-gate example.
- Current plan: bring the optional prefetch-assets template into `autoresearch.checks.sh` so the repo's architecture/performance docs and local validation safety net stay aligned.
