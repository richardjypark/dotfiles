# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment tightened the tracked repo-local Claude allowlist by removing wildcard WebFetch access. The current follow-up focuses on remaining low-hanging Codex metadata prompts for the specialized skills: several `agents/openai.yaml` files are still much weaker than the repo-maintainer prompt and do not nudge validation or trust-gate behavior early enough.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_agents/private_skills/chezmoi-script-maintainer/agents/openai.yaml` — Codex metadata prompt for setup-script work
- `private_dot_agents/private_skills/chezmoi-bootstrap-operator/agents/openai.yaml` — Codex metadata prompt for bootstrap/hardening work
- `private_dot_agents/private_skills/dotfiles-version-refresh/agents/openai.yaml` — Codex metadata prompt for version/external refresh work
- `docs/tooling-and-skills.md` / `AGENTS.md` / `ARCHITECTURE.md` — only if a minimal wording alignment becomes necessary

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
- Kept in earlier segments: Codex trust rationale and override mechanisms are now explicit, and the tracked repo-local Claude allowlist is narrower and documented as a project-local file.
- New insight after those prompt/config fixes: the repo-maintainer Codex metadata prompt is now high quality, but the three other specialized skill metadata prompts are still short and under-specified. They do not remind Codex about trust gates or subsystem-specific validation the way the underlying skill docs do.
- Current plan: strengthen the script-maintainer, bootstrap-operator, and version-refresh `agents/openai.yaml` prompts with concise reminders about trust gates, planning, and validation so Codex gets the right nudge before loading the full skill body.
