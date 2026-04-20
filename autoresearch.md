# Autoresearch: performance-summary helper discoverability cleanup

## Objective
Find and implement minimal, low-risk improvements to helper-command discoverability in the always-run performance summary script.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, the deferred Neovim semantics note was clarified inline, and several doc-consistency gaps were closed. The next promising path is another small discoverability cleanup: `run_after_99-performance-summary.sh` lists `czl` but still omits the macOS maintenance wrapper `czm`, even though README and tooling docs treat both as first-class maintenance helpers.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the performance-summary helper discoverability invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the performance summary script for whether it still omits the managed `czm` helper from its shortcut list.

## Files in Scope
- `.chezmoiscripts/run_after_99-performance-summary.sh` — always-run summary script missing `czm`
- `README.md` — canonical source of truth listing `czm` as a managed helper command
- `docs/tooling-and-skills.md` — canonical tooling doc listing `czm`

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
- Recent segments also fixed the stale `czl` global-npm wording, clarified the deferred Neovim version semantics inline, updated stale pre-run_onchange script references across the architecture/skill docs, and aligned helper-command wording in CLAUDE.md.
- New low-hanging discoverability gap: `run_after_99-performance-summary.sh` still lists `czl` but not `czm`, even though the canonical docs treat both as primary maintenance wrappers.
- Current plan: add `czm` to the summary script's shortcut list so macOS users see their platform-specific maintenance helper in the same place Arch users see `czl`.
