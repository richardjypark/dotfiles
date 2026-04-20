# Autoresearch: agent setup-template coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` also renders and parses the managed Claude Code, Pi CLI, and Codex setup templates.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, and the managed Claude/Pi settings targets. One adjacent script-validation gap remains for agent-tool installs: the lightweight safety net still skips the setup templates that provision Claude Code, Pi CLI, and Codex, even though those paths are part of the repo's tracked agent-tooling surface and the script-maintainer references already call out the Claude/Codex setup templates as canonical examples.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the managed agent-tool setup templates in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips rendering/parsing the managed Claude Code, Pi CLI, and Codex setup templates.

## Files in Scope
- `autoresearch.checks.sh` — should validate the managed agent-tool setup templates too
- `.chezmoiscripts/run_onchange_after_35-setup-claude-code.sh.tmpl` — managed Claude Code setup template
- `.chezmoiscripts/run_onchange_after_35-setup-pi-cli.sh.tmpl` — managed Pi CLI setup template
- `.chezmoiscripts/run_onchange_after_36-setup-codex.sh.tmpl` — managed Codex setup template
- `private_dot_agents/private_skills/chezmoi-script-maintainer/references/script-patterns.md` and README Pi-maintenance guidance — existing references that make these setup paths real maintained surfaces

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise template-parse check is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, and broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources and managed Claude/Pi settings JSON surfaces.
- Current plan: add the managed Claude Code, Pi CLI, and Codex setup templates so routine experiments inherit basic syntax coverage for the agent-tool installers too.
