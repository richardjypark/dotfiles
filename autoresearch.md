# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The current session focuses on committed agent configuration and instructions under `private_dot_claude/`, `private_dot_codex/`, `AGENTS.md`, `CLAUDE.md`, `docs/tooling-and-skills.md`, and `private_dot_agents/private_skills/`.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_claude/settings.json` — managed Claude client settings
- `CLAUDE.md` — Claude-facing repo instructions
- `docs/tooling-and-skills.md` — canonical skill/tooling guidance
- `private_dot_agents/private_skills/chezmoi-repo-maintainer/SKILL.md` — cross-cutting repo skill used for this surface
- `private_dot_codex/*` — only if a small alignment fix becomes clearly necessary
- `AGENTS.md` / `ARCHITECTURE.md` — only if a minimal wording alignment is needed

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
- Initial research identified one concrete security issue: committed Claude settings bypass the dangerous-mode permission prompt by default.
- Initial research also found a guidance gap: repo-level agent docs emphasize secure defaults, but Claude/client-config guidance does not explicitly say that approval/safety bypasses should stay opt-in and machine-local.
- Ideas to test first: remove the dangerous-mode bypass, then add concise guidance in the highest-leverage doc/skill surfaces so future agents do not reintroduce it.
