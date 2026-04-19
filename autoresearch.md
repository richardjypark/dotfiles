# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment finished the `jj` metadata prompt alignment and carried the repo-wide `jj status` reminder into the other mutating Codex entry points. The current follow-up focuses on one remaining metadata-prompt gap: the specialized prompts still omit the skill-specific read-first references from their `SKILL.md` files, so Codex gets validation/trust cues but not the highest-value docs to inspect first.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml` — setup-script Codex metadata prompt
- `private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml` — bootstrap Codex metadata prompt
- `private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml` — version-refresh Codex metadata prompt
- `private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md` — canonical read-first guidance for script work
- `private_dot_agents/private_skills/chezmoi-bootstrap-operator/SKILL.md` — canonical read-first guidance for bootstrap work
- `private_dot_agents/private_skills/dotfiles-version-refresh/SKILL.md` — canonical read-first guidance for version-refresh work

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
- Kept in recent segments: the `jj` metadata prompt now front-loads `jj status / jj log / jj diff`, carries a concise re-check / `jj undo` safety cue, and the other mutating Codex skill metadata prompts now also front-load `jj status`.
- New low-hanging gap from reviewing the remaining prompts: the specialized metadata prompts still omit the skill-specific read-first references (`script-patterns.md`, `bootstrap-matrix.md`, `version-map.md`) that the full skill bodies already treat as canonical.
- Current plan: add concise read-first reference cues to those three metadata prompts so Codex is nudged toward the authoritative docs before making subsystem-specific changes.
