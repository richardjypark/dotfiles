# Autoresearch: Pi keybindings render-safe coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` also validates the managed Pi keybindings JSON source and rendered target without relying on interactive apply prompts.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, and the agent-tool setup templates. A first attempt to cover `~/.pi/agent/keybindings.json` via `chezmoi apply --dry-run` proved unsafe for the loop because local drift on that target can trigger an interactive overwrite prompt and hang the checks. One adjacent Pi-config gap remains: the lightweight safety net still skips the sibling keybindings file even though the repo tracks `dot_pi/agent/keybindings.json` as part of the same managed Pi config surface, so the next fix should use a render-safe non-interactive path such as `chezmoi cat` plus JSON parsing.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the managed Pi keybindings surface in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips parsing `dot_pi/agent/keybindings.json` or non-interactively validating the rendered `~/.pi/agent/keybindings.json` target.

## Files in Scope
- `autoresearch.checks.sh` — should validate the managed Pi keybindings surface too
- `dot_pi/agent/keybindings.json` — managed Pi keybindings source
- `dot_pi/agent/settings.json` — adjacent managed Pi settings source already covered, used here as the symmetry baseline
- Pi's documented `~/.pi/agent/keybindings.json` path — the rendered target this repo manages

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise JSON-parse and non-interactive render check is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, and added managed Claude/Pi settings plus agent-tool setup-template coverage.
- A direct `chezmoi apply --dry-run ~/.pi/agent/keybindings.json` attempt timed out because local drift on the rendered file can force an interactive overwrite prompt. Current plan: keep the source-JSON check, but validate the rendered target through a non-interactive `chezmoi cat` + JSON parse path instead.
