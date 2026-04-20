# Autoresearch: version-data TOML parse coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation fix so `autoresearch.checks.sh` also parses the authoritative version-data TOML files.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes broadened CI syntax coverage across managed shell entrypoints, bootstrap scripts, and shared helper libraries, and broadened `autoresearch.checks.sh` across key rendered templates plus `.chezmoiexternal.toml.tmpl`. One concrete local-validation gap remains for version-refresh style changes: `autoresearch.checks.sh` still doesn't parse `.chezmoidata.toml` or `.chezmoiversion.toml`, even though repo guidance treats them as high-impact source-of-truth files.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the version-data TOML files in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips parsing `.chezmoidata.toml` and `.chezmoiversion.toml`.

## Files in Scope
- `autoresearch.checks.sh` — should parse the version-data TOML files too
- `.chezmoidata.toml` — authoritative template data and default branch source of truth
- `.chezmoiversion.toml` — authoritative version-pin source of truth
- `AGENTS.md`, `ARCHITECTURE.md`, and `dotfiles-version-refresh` guidance — already call out these files as high-impact surfaces

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
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, bootstrap scripts, and shared helper libraries, and broadened the local autoresearch safety net across `.chezmoiexternal.toml.tmpl` plus key setup templates.
- Current plan: add TOML parse coverage for `.chezmoidata.toml` and `.chezmoiversion.toml` so version-refresh style experiments inherit the same lightweight source-of-truth validation.
