# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment strengthened the specialized Codex skill metadata prompts. The current follow-up focuses on one remaining discoverability gap from `autoresearch.ideas.md`: `.claude/settings.local.json` is now security-relevant tracked project state, but the canonical cross-tool docs and routing docs still do not surface it clearly enough.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `docs/tooling-and-skills.md` — canonical cross-tool agent/tooling guidance
- `AGENTS.md` — high-impact agent-operating surface list
- `ARCHITECTURE.md` — agent-config routing table and key-files overview
- `.claude/settings.local.json` — tracked repo-local Claude permission allowlist referenced by the docs

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
- Kept in the latest segment: the specialized Codex metadata prompts for `chezmoi-script-maintainer`, `chezmoi-bootstrap-operator`, and `dotfiles-version-refresh` now front-load trust-gate and validation reminders instead of relying only on the full skill body.
- Next promising path from the ideas backlog: extend that `.claude/settings.local.json` explanation into `docs/tooling-and-skills.md`, and make sure the routing docs (`AGENTS.md` / `ARCHITECTURE.md`) acknowledge `.claude/` as an agent-config surface so future agents inspect it deliberately.
