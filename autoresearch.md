# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The current segment focuses on Codex-specific safety/discoverability gaps under `private_dot_codex/`, `docs/tooling-and-skills.md`, and `dot_local/bin/executable_chezmoi-health-check`.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against repo safety/prompt invariants.
- **Secondary**:
  - `security_findings` — findings that weaken security defaults
  - `guidance_findings` — missing or inconsistent prompt/skill guidance findings

## How to Run
`./autoresearch.sh`

The script audits a small set of high-signal invariants and prints structured `METRIC ...` lines.

## Files in Scope
- `private_dot_codex/private_config.toml.tmpl` — managed Codex config, including repo trust settings
- `private_dot_codex/AGENTS.md.tmpl` — Codex-facing routed AGENTS entry point
- `docs/tooling-and-skills.md` — canonical skill/tooling guidance
- `dot_local/bin/executable_chezmoi-health-check` — managed health-check helper; useful for lightweight agent-config sanity checks
- `AGENTS.md` / `CLAUDE.md` / `ARCHITECTURE.md` — only if a minimal wording alignment is needed

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
- Kept in earlier segments: `chezmoi-health-check` is now documented in README, CLAUDE.md, and `docs/tooling-and-skills.md`, with a canonical note that tracked client-config safety relaxations belong in local untracked overrides.
- The most promising remaining low-hanging idea from `autoresearch.ideas.md` is Codex-specific: `private_dot_codex/private_config.toml.tmpl` hardcodes `trust_level = "trusted"`, but the rationale and local-override path are not documented and the health check does not currently validate Codex's routed AGENTS/config files.
- Current plan: keep the Codex trusted-workspace default for now, but make it intentional and discoverable via comments/docs plus a lightweight operational sanity check. Avoid changing the default itself unless repo evidence clearly shows it is wrong.
