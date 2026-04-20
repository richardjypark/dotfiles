# Autoresearch: stale pre-run_onchange comment cleanup

## Objective
Find and remove any remaining low-risk stale references to the legacy `run_before_*` naming in source comments that should now point at `run_onchange_before_*`.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the helper-command discoverability/state-guidance cleanup is now largely spent down. A final small consistency pass is still justified if any source comments continue to mention the old pre-`run_onchange_*` naming even though the docs and skills were already updated.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of stale legacy `run_before_*` comment references still present in the targeted source scan.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — stale or misleading source comments

## How to Run
`./autoresearch.sh`

The script audits a narrow source/doc scan for legacy `run_before_*` wording that no longer matches the current `run_onchange_before_*` naming.

## Files in Scope
- `.chezmoiscripts/run_onchange_before_02-prefetch-assets.sh.tmpl` — currently contains a legacy `run_before_*` comment reference
- related docs/skills already aligned in earlier segments and used as the naming source of truth

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
- The larger stale doc/reference cleanup for `run_onchange_*` paths already landed earlier, so the only remaining low-risk follow-up is to catch any leftover source comments that still use the old naming.
- Current plan: fix the remaining legacy `run_before_*` comment reference if the narrow scan confirms it is unique.
