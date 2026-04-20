# Autoresearch: render-safe managed JSON target checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` validates the managed Claude and Pi JSON targets through non-interactive render paths instead of `chezmoi apply --dry-run`.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, and Pi keybindings. The key learning from the Pi keybindings segment is that target-specific `chezmoi apply --dry-run` checks can hang the loop when local drift triggers an interactive overwrite prompt. One adjacent robustness gap remains: the checks file still uses `apply --dry-run` for `~/.claude/settings.json` and `~/.pi/agent/settings.json`, even though both are JSON config targets that can be validated more directly and more safely through `chezmoi cat` plus JSON parsing.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining interactive-prone managed JSON target checks in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing render-safe validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips non-interactive rendered-JSON validation for `~/.claude/settings.json` and `~/.pi/agent/settings.json`.

## Files in Scope
- `autoresearch.checks.sh` — should validate these managed JSON targets through render-safe non-interactive checks
- `private_dot_claude/settings.json` — managed Claude settings source already parsed today
- `dot_pi/agent/settings.json` — managed Pi settings source already parsed today
- `~/.claude/settings.json` and `~/.pi/agent/settings.json` — rendered targets that are currently still validated through `apply --dry-run`

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise `chezmoi cat` + JSON parse check is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, and added managed Claude/Pi settings plus agent-tool setup-template coverage.
- The Pi keybindings segment proved that `chezmoi cat` keeps rendered-target validation while avoiding local-drift prompt hangs. Current plan: apply the same render-safe pattern to the remaining managed Claude/Pi JSON targets that still rely on `apply --dry-run`.
