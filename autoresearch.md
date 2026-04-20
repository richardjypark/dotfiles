# Autoresearch: externals template render coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` renders and parses `.chezmoiexternal.toml.tmpl` too.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes expanded CI syntax coverage across the managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and broadened `autoresearch.checks.sh` to cover the core rendered tool-setup templates. One concrete validation gap remains for version-refresh style changes: `autoresearch.checks.sh` still doesn't render and parse `.chezmoiexternal.toml.tmpl`, even though maintainer guidance already calls that file out as a key validation target.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for `.chezmoiexternal.toml.tmpl` render coverage in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips rendering/parsing `.chezmoiexternal.toml.tmpl`.

## Files in Scope
- `autoresearch.checks.sh` — should render/parse the externals template too
- `.chezmoiexternal.toml.tmpl` — high-impact externals source-of-truth template
- `private_dot_agents/private_skills/dotfiles-version-refresh/SKILL.md` — validation guidance already naming `.chezmoiexternal.toml.tmpl`

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the maintainer docs for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is docs-only.
- Validation must pass via `autoresearch.checks.sh`.
- Do not add vague prose if a concise command reference is enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- Recent helper-command discoverability/state-guidance passes surfaced `chezmoi-rerun-script` broadly, tightened `CLAUDE.md` so it now prefers targeted reruns over clearing all state, and cleaned up the remaining low-risk command-family symmetry gaps around `czm` in docs/comments.
- The latest validation-symmetry passes completed CI shell syntax coverage for the top-level managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and broadened the local autoresearch safety net across the prerequisites plus `uv`/`node`/`fzf` setup templates.
- Current plan: add `.chezmoiexternal.toml.tmpl` rendering/parsing to `autoresearch.checks.sh` so version-refresh style experiments inherit the same basic template safety net.
