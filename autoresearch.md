# Autoresearch: Neovim setup semantics clarification

## Objective
Find and implement minimal, low-risk improvements to how this repo documents the `run_onchange_after_24-setup-neovim.sh.tmpl` version semantics.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments, the low-hanging warm-apply work in the two remaining always-run scripts was addressed, and recent permission-cleanup passes removed most stale repo-local Claude Bash rules plus one stale explicit fetch domain. The next promising path is the deferred Neovim script semantics note: the script treats `REQUIRED_NVIM_VERSION` as the steady-state compatibility contract, while `PINNED_NVIM_VERSION` acts as the preferred install source when package managers lag. That distinction is currently implicit in code flow rather than explicit in comments.

## Metrics
- **Primary**: `issue_count` (unitless, lower is better) — number of audit findings against the Neovim setup semantics-documentation invariants for this segment.
- **Secondary**:
  - `security_findings` — concrete permission-surface problems
  - `guidance_findings` — missing health-check/drift-warning coverage

## How to Run
`./autoresearch.sh`

The script audits the Neovim setup script for an explicit inline note that distinguishes the required compatibility floor from the pinned preferred install source.

## Files in Scope
- `.chezmoiscripts/run_onchange_after_24-setup-neovim.sh.tmpl` — Neovim setup script whose version semantics need clarification
- `.chezmoidata.toml` — only for reference while validating the comment wording; do not change pins in this segment

## Off Limits
- Benchmark cheating: do not remove audit checks unless a stronger equivalent guarantee replaces them.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve secure defaults.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the audit by weakening it; improve the repo for principled reasons.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog: tracked Claude defaults are safer, docs and health checks are aligned, and Codex skill metadata now front-loads the key jj/read-first cues.
- Recent segments also spent down the low-hanging warm-apply work in the two remaining always-run scripts.
- Earlier segments spent down the low-hanging agent-safety/prompt backlog, improved the two remaining always-run warm paths, and then narrowed the tracked repo-local Claude allowlist plus aligned docs/health checks around the resulting policy.
- The older dispatcher/consolidation performance idea now looks mostly stale because only two always-run scripts remain and both already received their low-hanging warm-path cleanups.
- The remaining deferred script-maintenance path is Neovim semantics: `REQUIRED_NVIM_VERSION` is currently the compatibility floor enforced after install, while `PINNED_NVIM_VERSION` is only the preferred release binary source when package managers lag. That is visible from the code, but not stated directly.
- Current plan: add a concise inline comment near the version declarations so future maintainers do not conflate the compatibility floor with the preferred pinned release source.
