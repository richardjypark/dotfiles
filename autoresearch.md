# Autoresearch: agent safety low-hanging improvements

## Objective
Find and implement minimal, low-risk improvements to this dotfiles repo's agent-operating surfaces, especially around secure defaults, prompts, skills, and best-practice guidance.

The earlier Claude/docs/health-check safety gaps were closed in prior segments. The latest Codex segment added rationale/comments/checks around the trusted workspace default. The current follow-up focuses on making override guidance precise: earlier wording said to use generic local overrides, but closer inspection shows the repo should point to actual client-supported override mechanisms instead of vague or misleading paths.

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
- Kept in earlier segments: `chezmoi-health-check` is documented in README, CLAUDE.md, and `docs/tooling-and-skills.md`; Codex now documents why this repo is trusted by default, and health-check validates `~/.codex/AGENTS.md` plus `~/.codex/config.toml` presence.
- New insight after that Codex change: the repo still uses vague wording like "local untracked override" in agent docs, and the new Codex comment currently points at `~/.codex/config.toml` even though that file is itself managed here. The guidance should name real client-supported override mechanisms instead of implying a durable local file override that may be overwritten by chezmoi.
- Current plan: replace vague override language with concrete mechanisms. For Codex, prefer a per-run or wrapper-based `codex -c ...` override example. For Claude, prefer documented CLI/user/local settings sources such as `--settings` / `--setting-sources` rather than changing tracked repo defaults.
