# Autoresearch: generic Claude allowlist drift guard in chezmoi-health-check

## Objective
Find and implement a minimal, low-risk safety refinement so `chezmoi-health-check` warns about unexpected repo-local Claude Bash/WebFetch allowlist drift instead of only recognizing a hardcoded list of already-removed stale entries.

Recent segments tightened the tracked `.claude/settings.local.json` allowlist substantially, leaving only the apparent workflow primitives (`chezmoi`, `jj`, `git`, `zsh`, `tmux`) plus a small set of explicit WebFetch domains. The remaining idea backlog explicitly says further tightening now needs materially stronger evidence. One concrete gap remains regardless of whether those last permissions stay: `chezmoi-health-check` only checks for a fixed list of known-bad stale permissions, so a future unexpected Bash(...) or WebFetch(domain:...) entry could slip in without a targeted warning.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of missing generic repo-local Claude allowlist drift guards in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing drift-guard coverage

## How to Run
`./autoresearch.sh`

The script audits `dot_local/bin/executable_chezmoi-health-check` for whether it still lacks a generic unexpected-Bash allowlist check and a generic unexpected-WebFetch-domain check for `.claude/settings.local.json`.

## Files in Scope
- `dot_local/bin/executable_chezmoi-health-check` — should gain generic repo-local Claude allowlist drift guards
- `.claude/settings.local.json` — tracked project-local Claude permission policy file
- `autoresearch.ideas.md` — prune the now-stale remaining Claude-permission note if the new generic drift guard makes it non-actionable

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the allowlist checks or silently drop existing warnings.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current allowlist semantics; this segment is guardrail-only unless a genuinely stale idea should be pruned.
- Validation must pass via `autoresearch.checks.sh`.
- Prefer one generic parser-based drift check over growing an unbounded list of one-off grep warnings.

## What's Been Tried
- Earlier segments removed the easy stale Claude permission candidates (`WebFetch(domain:*)`, stale Influx fetch, `Bash(dscl:*)`, `tree`, `wc`, `cat`, `alias`, `czu`, `chmod`, `mkdir`, `source`) and added matching health-check warnings for them.
- The remaining allowlist now looks much more like true workflow primitives, which makes further permission tightening less certain and shifts the best low-risk win from removing entries to guarding against unexpected future broadening.
- Current plan: add a generic health-check comparison against the expected Bash/WebFetch allowlist for `.claude/settings.local.json`, then prune the stale ideas backlog note if no concrete immediate tightening path remains.
