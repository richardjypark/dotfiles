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
- `README.md` — user-facing command/workflow documentation
- `CLAUDE.md` — Claude-facing repo instructions
- `docs/tooling-and-skills.md` — canonical skill/tooling guidance
- `private_dot_agents/private_skills/chezmoi-repo-maintainer/SKILL.md` — cross-cutting repo skill used for this surface
- `private_dot_agents/private_skills/chezmoi-repo-maintainer/agents/openai.yaml` — Codex-facing metadata prompt for the cross-cutting repo skill
- `private_dot_codex/*` — only if a small alignment fix becomes clearly necessary
- `dot_local/bin/executable_chezmoi-health-check` — managed health-check helper; useful for lightweight agent-config sanity checks
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
- Initial research identified one concrete security issue: committed Claude settings bypassed the dangerous-mode permission prompt by default.
- Kept: `private_dot_claude/settings.json` now keeps that prompt enabled by default, and concise guardrails were added to `CLAUDE.md` plus the shared `chezmoi-repo-maintainer` skill so tracked client-config safety bypasses stay opt-in and local-only.
- The first audit was too loose to detect the guidance gap directly, but the docs/skill reinforcement was still worth keeping because it protects against regression around the security fix.
- Kept: `CLAUDE.md` now has a concise First Pass checklist, and the repo-maintainer Codex metadata prompt now nudges read order, planning, and chezmoi validation.
- Kept: `chezmoi-health-check` now validates shared agent-skill routing and the Claude dangerous-mode permission prompt default.
- Kept: `README.md` documents `chezmoi-health-check`, and `docs/tooling-and-skills.md` now states that tracked client-config safety bypasses belong in local untracked overrides.
- Next promising low-hanging improvement: surface `chezmoi-health-check` in the agent-facing/tooling reference docs (`CLAUDE.md` and `docs/tooling-and-skills.md`) so it is discoverable from the places agents actually read during maintenance work.
