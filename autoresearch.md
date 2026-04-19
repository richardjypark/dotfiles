# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest Codex segment clarified trusted-workspace rationale and precise override mechanisms. The current follow-up focuses on the repo-local Claude permissions file: `.claude/settings.local.json` is tracked and currently allows `WebFetch(domain:*)`, which is broader than the repo's security posture suggests.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `.claude/settings.local.json` — tracked repo-local Claude permissions allowlist for this repo
- `CLAUDE.md` — Claude-facing repo instructions
- `docs/tooling-and-skills.md` — canonical skill/tooling guidance
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
- Kept in earlier segments: Claude no longer bypasses dangerous-mode confirmation by default; CLAUDE/docs/skills now carry matching safety and first-pass guidance; `chezmoi-health-check` now validates shared skill routing and Claude's prompt setting.
- Kept in earlier segments: `chezmoi-health-check` is documented in README, CLAUDE.md, and `docs/tooling-and-skills.md`; Codex now documents why this repo is trusted by default, validates routed AGENTS/config files, and points to concrete override mechanisms (`codex -c ...`).
- New insight after that work: the tracked repo-local Claude settings file still contains `WebFetch(domain:*)`. That is broader than the repo's security posture and makes the more specific domain allowlist entries redundant.
- Current plan: tighten `.claude/settings.local.json` to domain-scoped fetch permissions, document that the file is a tracked repo-local allowlist rather than a personal override file, and add a cheap health-check warning so wildcard fetch permissions do not creep back in.
