# Autoresearch: bootstrap doc maintenance-wrapper symmetry cleanup

## Objective
Find and implement a minimal, low-risk consistency fix in `docs/bootstrap-and-flags.md` so its update-helper intro line includes the macOS maintenance wrapper `czm` alongside the already-documented `czl`.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the helper-command discoverability/state-guidance cleanup is now largely spent down. One small doc-consistency gap remains in the bootstrap flags doc: the intro line above the helper bullets still lists `czu`, `czuf`, and `czl` but omits `czm`, even though the bullets below already document both platform-specific maintenance wrappers.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of bootstrap-doc helper-list omissions for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — stale or misleading doc wording

## How to Run
`./autoresearch.sh`

The script audits `docs/bootstrap-and-flags.md` for whether its update-helper intro line still omits `czm` while the rest of the section documents it.

## Files in Scope
- `docs/bootstrap-and-flags.md` — update-helper intro line still omits `czm`
- `README.md` and `docs/tooling-and-skills.md` — source-of-truth docs already treating `czm` as a first-class maintenance wrapper

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the maintainer docs for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is docs-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise command reference is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- Recent helper-command discoverability/state-guidance passes surfaced `chezmoi-rerun-script` broadly and tightened `CLAUDE.md` so it now prefers targeted reruns over clearing all state.
- The larger stale doc/reference cleanup for `run_onchange_*` paths is now effectively complete, including the last targeted source comment.
- Current plan: clean up one remaining command-family symmetry gap where `docs/bootstrap-and-flags.md` names `czl` but omits `czm` in the section intro despite documenting both below.
