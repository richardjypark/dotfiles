# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment finished the `jj` metadata prompt alignment by adding both first-pass inspection and rewrite-recovery cues. The current follow-up focuses on a cross-cutting consistency gap: the other Codex skill metadata prompts still do not front-load the repo's universal `jj status` check before editing.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_agents/private_skills/chezmoi-repo-maintainer/agents/openai.yaml` — cross-cutting Codex metadata prompt
- `private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml` — setup-script Codex metadata prompt
- `private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml` — bootstrap Codex metadata prompt
- `private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml` — version-refresh Codex metadata prompt
- `AGENTS.md` — source of truth for the repo-wide first-pass `jj status` requirement

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
- Kept in the latest segment: the `jj` metadata prompt now front-loads `jj status / jj log / jj diff` and carries a concise re-check / `jj undo` safety cue.
- Next promising micro-improvement: carry the repo-wide `jj status` first-pass reminder into the other Codex metadata prompts so the universal tree-state check is not only implicit in AGENTS.md.
