# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment added skill-specific read-first references to the specialized Codex metadata prompts. The current follow-up focuses on one last small `jj` metadata gap: the prompt now covers inspect-first and rewrite-recovery behavior, but it still does not surface the skill body's publish-safety cue to confirm the bookmark target before pushing.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_agents/private_skills/jj/agents/openai.yaml` — Codex metadata prompt for jj workflows
- `private_dot_agents/private_skills/jj/SKILL.md` — canonical publish/recovery workflow guidance
- `private_dot_agents/private_skills/jj/references/jj-reference.md` — detailed jj publish/recovery reference

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
- Kept in earlier segments: stale `Bash(dscl:*)` access was removed from the tracked repo-local Claude allowlist, with a matching health-check warning to catch regressions.
- Kept in recent segments: the `jj` metadata prompt now front-loads `jj status / jj log / jj diff`, carries a concise re-check / `jj undo` safety cue, and the other mutating Codex skill metadata prompts now front-load `jj status` plus their canonical read-first references.
- Remaining small `jj` gap from reviewing the full skill body: the metadata prompt still does not remind Codex to confirm the bookmark target before publishing, even though bookmark/remote ambiguity is one of the most expensive `jj` mistakes.
- Current plan: add one concise publish-safety cue (`jj bookmark list` or equivalent target-confirmation wording) without turning the metadata prompt into a full command reference.
