# Autoresearch: cz* command wording consistency cleanup

## Objective
Find and implement minimal, low-risk improvements to consistency in how the repo documents the managed `cz*` helper commands.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, the deferred Neovim semantics note was clarified inline, and stale script-path/docs references were updated. The next promising path is another small consistency cleanup: README already says the `cz*` helpers are managed commands installed in `~/.local/bin`, but `CLAUDE.md` still calls them aliases and the performance summary script still labels `czvc`/`czb` as aliases.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the `cz*` command wording consistency invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the Claude-facing docs and the performance summary script for stale alias wording around the managed `cz*` helper commands.

## Files in Scope
- `CLAUDE.md` — Claude-facing maintenance doc that still calls the helpers aliases
- `.chezmoiscripts/run_after_99-performance-summary.sh` — summary script that still labels `czvc`/`czb` as aliases
- `README.md` — canonical source of truth stating that `cz*` helpers are managed commands in `~/.local/bin`

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
- Recent segments also fixed the stale `czl` global-npm wording, clarified the deferred Neovim version semantics inline, and updated stale pre-run_onchange script references across the architecture/skill docs.
- New low-hanging doc gap: README already says the `cz*` helpers are managed commands in `~/.local/bin`, but `CLAUDE.md` and the performance summary script still call some of them aliases.
- Current plan: align those remaining surfaces with the canonical command wording so agents and humans get one consistent mental model.
