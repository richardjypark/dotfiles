# Autoresearch: performance-summary rerun-helper discoverability cleanup

## Objective
Find and implement minimal, low-risk improvements to discoverability for the managed `chezmoi-rerun-script` helper in the always-run apply summary.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, the deferred Neovim semantics note was clarified inline, and several doc-consistency gaps were closed. The next promising path is another discoverability cleanup: README, CLAUDE.md, and docs/tooling-and-skills.md now all surface `chezmoi-rerun-script`, but the always-run performance summary still does not mention the helper.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the performance-summary rerun-helper discoverability invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the always-run performance summary script for whether it still omits the managed `chezmoi-rerun-script` helper.

## Files in Scope
- `.chezmoiscripts/run_after_99-performance-summary.sh` — always-run summary script missing `chezmoi-rerun-script`
- `README.md` — canonical source of truth already documenting `chezmoi-rerun-script`
- `CLAUDE.md` / `docs/tooling-and-skills.md` — maintenance docs that now surface the helper and can anchor the summary wording

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
- Recent segments also fixed the stale `czl` global-npm wording, clarified the deferred Neovim version semantics inline, updated stale pre-run_onchange script references across the architecture/skill docs, aligned helper-command wording in CLAUDE.md, surfaced `czm` in the performance summary, and surfaced `chezmoi-rerun-script` in the maintenance docs.
- New low-hanging discoverability gap: the always-run performance summary still omits `chezmoi-rerun-script`, even though the helper is now documented in the main maintenance docs.
- Current plan: add `chezmoi-rerun-script` to the summary helper list so users see the run_onchange recovery helper alongside the other managed maintenance commands.
