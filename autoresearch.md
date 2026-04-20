# Autoresearch: replace remaining apply-time target checks with render-safe validation

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` stops relying on `chezmoi apply --dry-run` for the remaining managed target checks.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, and Pi keybindings. The strongest recent lesson is that target-specific `chezmoi apply --dry-run` checks are fragile in an autoresearch loop because local drift can trigger interactive overwrite prompts and hang the run. The JSON targets have already been converted to `chezmoi cat` plus parsing, but one robustness gap remains: the checks file still keeps a final `apply --dry-run` block for `~/.codex/config.toml`, `~/.codex/AGENTS.md`, the rendered skill metadata YAML files, and `~/.local/bin/chezmoi-health-check`, even though all of these can be validated through non-interactive render-safe paths too.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining managed target checks that still rely on `chezmoi apply --dry-run` instead of render-safe validation in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing render-safe validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips render-safe validation for the remaining managed targets or still retains the final `chezmoi apply --dry-run` block.

## Files in Scope
- `autoresearch.checks.sh` — should validate the remaining managed targets through render-safe non-interactive checks
- `private_dot_codex/private_config.toml.tmpl` / `~/.codex/config.toml` — Codex config surface
- `private_dot_codex/AGENTS.md.tmpl` / `~/.codex/AGENTS.md` — rendered Codex AGENTS entry point
- `~/.agents/skills/*/agents/openai.yaml` — rendered skill metadata YAML targets
- `dot_local/bin/executable_chezmoi-health-check` / `~/.local/bin/chezmoi-health-check` — rendered health-check script target

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if concise `chezmoi cat` + parser/render checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, broadened `autoresearch.checks.sh` across high-leverage templates plus the authoritative externals/version-data TOML sources, and added managed Claude/Pi settings plus agent-tool setup-template coverage.
- The Pi keybindings and managed JSON-target segments showed that `chezmoi cat` preserves rendered-target validation while avoiding drift-induced apply prompts. Current plan: extend that render-safe pattern to the remaining Codex, skill-metadata, and rendered health-check targets so the checks file no longer depends on `apply --dry-run` at all.
