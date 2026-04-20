# Autoresearch: CLAUDE maintenance-wrapper discoverability cleanup

## Objective
Find and implement minimal, low-risk improvements to maintenance-wrapper discoverability in `CLAUDE.md`.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, the deferred Neovim semantics note was clarified inline, and several doc-consistency gaps were closed. The next promising path is another small discoverability cleanup: `CLAUDE.md` now mentions the generic helpers (`czu`, `czuf`, `czvc`, `czb`), but it still omits the platform-specific maintenance wrappers `czl` and `czm` that README and tooling docs treat as first-class helpers.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the CLAUDE maintenance-wrapper discoverability invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits `CLAUDE.md` for whether it still omits the platform-specific `czl` and `czm` maintenance wrappers from the compact helper-command note.

## Files in Scope
- `CLAUDE.md` — Claude-facing maintenance doc missing `czl`/`czm`
- `README.md` — canonical source of truth listing `czl` and `czm`
- `docs/tooling-and-skills.md` — canonical tooling doc listing `czl` and `czm`

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
- Recent segments also fixed the stale `czl` global-npm wording, clarified the deferred Neovim version semantics inline, updated stale pre-run_onchange script references across the architecture/skill docs, aligned helper-command wording in CLAUDE.md, and added `czm` to the performance summary helper list.
- New low-hanging discoverability gap: `CLAUDE.md` still omits the platform-specific maintenance wrappers `czl` and `czm` even though the canonical docs treat them as first-class helpers.
- Current plan: add `czl` and `czm` to the compact helper-command note in `CLAUDE.md` so the short maintenance doc better mirrors the broader command references.
