# Autoresearch: core tool-setup template coverage in autoresearch checks

## Objective
Find and implement minimal, low-risk validation fixes so `autoresearch.checks.sh` parses the core tool-setup templates that maintainer skills already single out.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain, and the low-risk helper-command/state-guidance/doc-symmetry cleanup is now mostly spent down. The latest validation-symmetry passes expanded CI syntax coverage across the managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and added the prerequisites template to `autoresearch.checks.sh`. A remaining local validation gap is that `autoresearch.checks.sh` still omits the core rendered tool-setup templates for `uv`, `node`, and `fzf` that the maintainer skills already call out in their validation sections.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining autoresearch-check omissions for the core rendered tool-setup templates in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing local validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips the rendered `uv`, `node`, and `fzf` setup templates referenced by the maintainer skills' validation guidance.

## Files in Scope
- `autoresearch.checks.sh` — should template-parse the core tool-setup templates too
- `.chezmoiscripts/run_onchange_after_25-setup-uv.sh.tmpl`
- `.chezmoiscripts/run_onchange_after_30-setup-node.sh.tmpl`
- `.chezmoiscripts/run_onchange_after_20-setup-fzf.sh.tmpl`
- `private_dot_agents/private_skills/chezmoi-script-maintainer/SKILL.md` and `private_dot_agents/private_skills/dotfiles-version-refresh/SKILL.md` — source-of-truth validation guidance already naming these templates

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
- The latest validation-symmetry passes completed CI shell syntax coverage for the top-level managed bin directory, the Pi maintenance-agent helper, and the documented bootstrap/hardening scripts, and added the prerequisites template to the local autoresearch safety net.
- Current plan: extend `autoresearch.checks.sh` to the `uv`, `node`, and `fzf` templates that maintainer skills already single out in their validation examples.
