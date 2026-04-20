# Autoresearch: autoresearch.checks.sh runtime without reducing coverage

## Objective
Find and implement a minimal, low-risk speedup for `autoresearch.checks.sh` while preserving its current validation coverage and loop-safety guarantees.

Recent segments spent down a long list of concrete local-validation gaps, and `autoresearch.checks.sh` now covers the repo's high-impact config, script, bootstrap, helper-library, and command-entrypoint surfaces much more broadly. The next promising path is no longer more coverage breadth by default, but reducing the cost of running that broader safety net. Any change in this segment must preserve the same checks and avoid reintroducing interactive `chezmoi apply --dry-run` behavior.

## Metrics
- **Primary**: `total_ms` (milliseconds, lower is better) — wall-clock time to run `autoresearch.checks.sh` for a fixed small loop count.
- **Secondary**:
  - `per_run_ms` — average milliseconds per `autoresearch.checks.sh` run
  - `loops` — benchmark loop count used for stability

## How to Run
Use an inline Python benchmark that runs `./autoresearch.checks.sh` repeatedly and emits:
- `METRIC total_ms=...`
- `METRIC per_run_ms=...`
- `METRIC loops=...`

## Files in Scope
- `autoresearch.checks.sh` — optimize structure without weakening coverage
- `autoresearch.ideas.md` — prune/add ideas only if a promising but deferred optimization is discovered

## Off Limits
- Benchmark cheating or audit cheating: do not remove or weaken checks just to make the benchmark faster.
- Reintroducing `chezmoi apply --dry-run` on drift-prone targets.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.

## Constraints
- Keep changes minimal and low risk.
- Preserve validation semantics.
- Validation must still pass via `autoresearch.checks.sh` after the benchmark command completes.
- Prefer structure changes like batching or safe parallelization of independent read-only checks over semantic changes.

## What's Been Tried
- Earlier segments tightened agent safety, broadened local validation coverage, and replaced interactive-prone rendered-target checks with render-safe `chezmoi cat` + parser validation.
- The two remaining always-run apply scripts were already micro-optimized earlier; recent work instead focused on coverage symmetry and now leaves `autoresearch.checks.sh` as the main recurring local-loop cost.
- Current plan: baseline the widened checks script, then try a low-risk structural speedup such as grouping independent read-only checks into a few parallel batches while keeping the stateful tmux/temp-home validation path serialized.
