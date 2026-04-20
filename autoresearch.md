# Autoresearch: remaining apply-time script coverage in autoresearch checks

## Objective
Find and implement a minimal, low-risk validation refinement so `autoresearch.checks.sh` also syntax-checks the remaining unchecked apply-time scripts under `.chezmoiscripts/`.

The latest local-validation passes broadened `autoresearch.checks.sh` across key rendered templates, authoritative TOML/JSON config surfaces, managed Claude/Pi settings targets, agent-tool setup templates, rendered shell/tmux configs, documented bootstrap/hardening entrypoints, shared helper libraries, user-facing command entrypoints, maintenance-agent shell entrypoints, and the optional prefetch-assets / Tailscale templates. One bounded high-impact gap remains: `AGENTS.md` explicitly treats `.chezmoiscripts/` plus the helper contract as a high-impact surface, but a small residual set of apply-time scripts is still outside the lightweight local safety net.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of remaining unchecked `.chezmoiscripts/*` entrypoints in this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing apply-time script validation coverage

## How to Run
`./autoresearch.sh`

The script audits `autoresearch.checks.sh` for whether it still skips the remaining unchecked apply-time scripts under `.chezmoiscripts/`.

## Files in Scope
- `autoresearch.checks.sh` — should syntax-check the remaining unchecked apply-time scripts too
- `.chezmoiscripts/run_onchange_after_10-setup-homebrew.sh`
- `.chezmoiscripts/run_onchange_after_12-setup-starship.sh.tmpl`
- `.chezmoiscripts/run_onchange_after_26-setup-jj.sh.tmpl`
- `.chezmoiscripts/run_onchange_after_27-setup-bun.sh.tmpl`
- `.chezmoiscripts/run_onchange_after_28-setup-ansible.sh`
- `.chezmoiscripts/run_onchange_after_31-change-shell.sh`
- `.chezmoiscripts/run_onchange_after_40-setup-tmux.sh.tmpl`
- `.chezmoiscripts/run_onchange_before_01-setup-omz.sh`
- `AGENTS.md` — already flags `.chezmoiscripts/` as a high-impact surface

## Off Limits
- Benchmark cheating or audit cheating: do not weaken the audit; improve the local safety net for principled reasons.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve current script behavior; this segment is checks-only.
- Validation must pass via `autoresearch.checks.sh`.
- Use `chezmoi execute-template ... | bash -n` for templated scripts and direct `bash -n` for non-templated scripts.
- Do not add vague prose if concise syntax checks are enough.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, tightened the tracked repo-local Claude allowlist, and aligned docs plus health checks around the resulting policy.
- Recent segments also improved the two remaining always-run warm paths individually and then measured their combined residual cost at about 5.6 ms per apply in the current harness, which makes further performance work look deeper by nature.
- The latest validation-symmetry passes completed CI shell syntax coverage for managed shell entrypoints, shared helper libraries, and key rendered/user-facing config surfaces; the local autoresearch safety net now mirrors most of those checks, including shell/tmux configs, bootstrap entrypoints, helper libraries, command entrypoints, maintenance-agent entrypoints, and several high-leverage setup templates.
- Current plan: finish the local `.chezmoiscripts/` syntax-coverage sweep by adding the last bounded residual set of apply-time scripts to `autoresearch.checks.sh`.
