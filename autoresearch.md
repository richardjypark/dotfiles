# Autoresearch: CLAUDE state-file guidance cleanup

## Objective
Find and implement a minimal, low-risk improvement to `CLAUDE.md` so its state-file guidance prefers the managed one-script rerun helper before suggesting a full state wipe.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and recent helper-command discoverability cleanups surfaced `chezmoi-rerun-script` across user docs, maintainer docs, and the always-run performance summary. One obvious guidance gap remains: `CLAUDE.md` still tells maintainers to clear the entire chezmoi state directory to rerun scripts, even though the repo now has a managed helper for targeted one-script reruns.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining CLAUDE state-guidance omissions for targeted reruns.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing or overly-broad maintainer guidance

## How to Run
`./autoresearch.sh`

The script audits `CLAUDE.md` to make sure its `State files` guidance mentions `chezmoi-rerun-script` for one-script reruns and reserves clearing `~/.cache/chezmoi-state/` for full reruns.

## Files in Scope
- `CLAUDE.md` — current state-file guidance is broader than necessary
- `README.md`, `docs/tooling-and-skills.md`, and `ARCHITECTURE.md` — existing source-of-truth docs that already mention `chezmoi-rerun-script`

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
- Recent helper-command discoverability passes surfaced `chezmoi-rerun-script` in README, `docs/tooling-and-skills.md`, the always-run performance summary, `ARCHITECTURE.md`, `docs/architecture-and-performance.md`, and the script-maintainer skill.
- The remaining low-risk guidance gap is now very narrow: `CLAUDE.md` still suggests clearing the whole state directory without first steering maintainers to the sanctioned one-script rerun helper.
- Current plan: tighten that one `CLAUDE.md` bullet so it distinguishes targeted reruns from full reruns.
