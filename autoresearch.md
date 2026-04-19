# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment removed stale `Bash(dscl:*)` access from the tracked repo-local Claude allowlist. The current follow-up focuses on the remaining metadata-prompt inconsistency: the `jj` Codex metadata prompt is still much weaker than the underlying skill body and does not front-load the repo's preferred first-pass/recheck workflow.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_agents/private_skills/jj/agents/openai.yaml` — Codex metadata prompt for Jujutsu workflows
- `private_dot_agents/private_skills/jj/SKILL.md` — canonical jj workflow guidance the metadata prompt should align with
- `private_dot_agents/private_skills/jj/references/jj-reference.md` — detailed jj reference used to confirm high-leverage reminders

## Off Limits
- Benchmark cheating: do not remove audit checks unless a stronger equivalent guarantee replaces them.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.
- Broad prompt rewrites or style-only edits with no measurable audit improvement.

## Constraints
- Keep changes minimal and low risk.
- Preserve secure defaults.
- Prefer one source of truth; avoid duplicated guidance unless the duplication is intentionally cross-tool.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the audit by weakening it; improve the repo so the audit passes for principled reasons.

## What's Been Tried
- Kept in earlier segments: Claude no longer bypasses dangerous-mode confirmation by default; CLAUDE/docs/skills now carry matching safety and first-pass guidance; `chezmoi-health-check` now validates shared skill routing, Codex routed files, and Claude prompt/permission defaults.
- Kept in earlier segments: Codex trust rationale and override mechanisms are now explicit, and the tracked repo-local Claude allowlist is narrower, documented as a project-local file, and surfaced in canonical/routing docs.
- Kept in the latest segment: stale `Bash(dscl:*)` access was removed from the tracked repo-local Claude allowlist, with a matching health-check warning to catch regressions.
- Next promising path: the `jj` metadata prompt still says less than the skill body. It should at least nudge Codex toward `jj status`/`jj log`/`jj diff` before history changes and toward re-checking state after rewrites.
