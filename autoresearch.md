# Autoresearch: repo-local Claude fetch-domain cleanup

## Objective
Find and implement minimal, low-risk improvements to the tracked repo-local Claude fetch permission surface.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, and the latest segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts. Recent permission-cleanup passes also removed the easiest stale repo-local Claude Bash rules. The next promising path is an explicit fetch-domain cleanup: `.claude/settings.local.json` still allows `WebFetch(domain:eu-central-1-1.aws.cloud2.influxdata.com)`, but repo source/docs do not appear to reference that domain or an Influx-backed workflow.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the repo-local Claude fetch-domain invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits `.claude/settings.local.json` and `dot_local/bin/executable_chezmoi-health-check` for one evidence-backed stale fetch domain and its matching drift warning.

## Files in Scope
- `.claude/settings.local.json` — tracked repo-local Claude allowlist
- `dot_local/bin/executable_chezmoi-health-check` — drift warning surface for repo-local Claude permissions

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
- Recent segments removed stale `Bash(dscl:*)`, `Bash(tree:*)`, `Bash(wc:*)`, `Bash(cat:*)`, and `Bash(alias:*)` access from the tracked allowlist, each with a matching health-check warning.
- Remaining Bash permissions now look materially harder to trim: `chezmoi`, `jj`, `git`, `zsh`, `tmux`, `mkdir`, `chmod`, `source`, and `czu` all have clearer repo workflow grounding.
- New evidence: exact searches across repo docs/source do not show `eu-central-1-1.aws.cloud2.influxdata.com` or `influxdata`, making that explicit WebFetch domain look like stale leftover permission scope rather than an intentional repo requirement.
- Current plan: remove the Influx fetch domain from `.claude/settings.local.json` and add a matching health-check warning so it does not silently return.
