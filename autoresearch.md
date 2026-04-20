# Autoresearch: bootstrap entrypoint coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the repo's documented bootstrap and hardening entrypoints locally.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, and the remaining render-safe managed targets that previously relied on `chezmoi apply --dry-run`. One concrete routing gap remains: the bootstrap entrypoints `scripts/bootstrap-omarchy.sh`, `bootstrap-vps.sh`, and `scripts/server-lockdown-tailscale.sh` are explicitly called out as high-impact surfaces in `AGENTS.md`, `ARCHITECTURE.md`, README, and the bootstrap skill, and they already have canonical `bash -n` validation guidance — but the lightweight local autoresearch safety net still doesn't check them.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing local bootstrap/hardening entrypoint checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing bootstrap validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips local syntax checks for the documented bootstrap and hardening entrypoints.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the bootstrap/hardening entrypoints too
- `scripts/bootstrap-omarchy.sh` — Omarchy bootstrap entrypoint
- `bootstrap-vps.sh` — Debian/Ubuntu VPS bootstrap entrypoint
- `scripts/server-lockdown-tailscale.sh` — post-bootstrap hardening entrypoint
- `AGENTS.md`, `ARCHITECTURE.md`, README, and `chezmoi-bootstrap-operator` guidance — already define these files as high-impact and worth validating

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
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, added managed Claude/Pi settings plus agent-tool setup-template coverage, replaced the remaining `apply --dry-run` target checks with render-safe validation, and aligned the local safety net with the documented shell/tmux checks.
- Current plan: pull the bootstrap skill's own `bash -n` guidance into `autoresearch.checks.sh` so local experiments inherit the same high-impact entrypoint coverage that CI and the maintainer docs already expect.
