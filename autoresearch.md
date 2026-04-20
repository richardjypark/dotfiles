# Autoresearch: shell/tmux rendered-config coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also validates the rendered shell and tmux config targets that the repo's maintainer checklist already treats as high-impact.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, and the remaining render-safe managed targets that previously relied on `chezmoi apply --dry-run`. One concrete validation-routing gap remains: `AGENTS.md` and `ARCHITECTURE.md` both single out `~/.zshrc` and `~/.tmux.conf` validation when shell/tmux behavior changes, but the lightweight autoresearch safety net still doesn't render-check those two daily-use targets. This is a principled gap rather than generic coverage hunting because both files are explicitly called out as high-impact surfaces and have canonical validation commands already documented.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing render-safe shell/tmux target checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing rendered shell/tmux validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips render-safe validation for `~/.zshrc` and `~/.tmux.conf`.

## Files in Scope
- `autoresearch.checks.sh` — should validate the rendered shell/tmux targets too
- `dot_zshrc.tmpl` / `~/.zshrc` — high-impact rendered shell config surface
- `dot_tmux.conf` / `~/.tmux.conf` — high-impact rendered tmux config surface
- `AGENTS.md` and `ARCHITECTURE.md` — already define the canonical validation expectations for these surfaces

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Keep the tmux validation isolated from the user's real tmux server/session.
- Do not add vague prose if concise render-safe checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, added managed Claude/Pi settings plus agent-tool setup-template coverage, and then replaced the remaining `apply --dry-run` target checks with render-safe validation.
- Current plan: align the local autoresearch safety net with the repo's shell/tmux validation checklist by adding a rendered `zsh -n` check for `~/.zshrc` and an isolated-socket tmux source check for `~/.tmux.conf`.
