# Autoresearch: script-doc path consistency cleanup

## Objective
Find and implement minimal, low-risk improvements to consistency between the actual `.chezmoiscripts/` paths and the docs/skill references that point at them.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, the deferred Neovim semantics note was clarified inline, and one stale `czl` doc path was aligned. The next promising path is another consistency cleanup: several skill/reference docs still point at old `run_after_*` / `run_before_*` script paths even though most of those setup scripts were converted to `run_onchange_*` long ago.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the script-doc path consistency invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits a small set of docs/skill files for stale `.chezmoiscripts/run_after_*` or `.chezmoiscripts/run_before_*` references that should now point at `run_onchange_*` paths.

## Files in Scope
- `ARCHITECTURE.md` — high-level apply-time script routing
- `docs/architecture-and-performance.md` — validation checklist
- `private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md` — script-maintainer workflow/validation guidance
- `private_dot_agents/private_skills/chezmoi-script-maintainer/references/script-patterns.md` — canonical script reference examples
- `private_dot_agents/private_skills/dotfiles-version-refresh/SKILL.md` — version-refresh validation examples
- `private_dot_agents/private_skills/dotfiles-version-refresh/references/version-map.md` — script touchpoint map

## Off Limits
- Benchmark cheating: do not remove audit checks unless a stronger equivalent guarantee replaces them.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve secure defaults.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the audit by weakening it; improve the repo for principled reasons.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog: tracked Claude defaults are safer, docs and health checks are aligned, and Codex skill metadata now front-loads the key jj/read-first cues.
- Recent segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts.
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, improved the two remaining always-run warm paths, and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- The older dispatcher/consolidation performance idea now looks mostly stale because only two always-run scripts remain and both already received their low-hanging warm-path cleanups.
- Recent segments also fixed the stale `czl` global-npm wording and clarified the deferred Neovim version semantics inline.
- New low-hanging doc gap: several docs/skill references still name legacy `run_after_*` / `run_before_*` paths even though the actual scripts are now mostly `run_onchange_*`.
- Current plan: update those references to the canonical current paths so future agents do not chase nonexistent script names when validating or editing setup logic.
