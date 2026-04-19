# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest segment surfaced `.claude/settings.local.json` in the canonical/routing docs. The current follow-up focuses on one evidence-backed permission tightening: the tracked repo-local Claude allowlist still includes `Bash(dscl:*)`, but `dscl` does not appear to be part of this repo's documented or implemented workflows.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `.claude/settings.local.json` — tracked repo-local Claude permission allowlist
- `dot_local/bin/executable_chezmoi-health-check` — managed health-check helper for permission drift checks
- `CLAUDE.md` / `docs/tooling-and-skills.md` — only if a tiny wording alignment becomes necessary

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
- New evidence from the remaining allowlist review: `Bash(dscl:*)` still exists in `.claude/settings.local.json`, but `dscl` does not show up in repo source files or the repo's user-facing/agent-facing workflow docs. It looks like stale leftover permission scope rather than an intentional repo need.
- Current plan: remove `Bash(dscl:*)` from the tracked allowlist and add a cheap health-check warning so unrelated macOS account-management permissions do not creep back in without review.
