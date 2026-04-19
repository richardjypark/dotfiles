# Autoresearch: warm apply hot-path cleanup

## Objective
Find and implement minimal, low-risk improvements to the remaining always-run chezmoi scripts that still affect warm apply time.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments. The low-hanging prompt alignment work now looks mostly exhausted, so this segment returns to warm-apply performance. A recent pass already made `.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl` much cheaper on unsupported hosts with no opt-in marker. The next target is the default non-verbose path in `.chezmoiscripts/run_after_99-performance-summary.sh`, which still runs on every apply and can likely exit a bit earlier before carrying verbose-only setup cost.

## Metrics
- **Primary**: `total_us` (µs, lower is better) — total wall-clock time for repeatedly executing `run_after_99-performance-summary.sh` in a controlled non-verbose benchmark harness with a representative warm state directory.
- **Secondary**:
  - `per_run_us` — average warm-path cost per script invocation
  - `loops` — benchmark iteration count used for the run

## How to Run
`./autoresearch.sh`

The script builds a temporary state directory with representative `.done` markers, runs `.chezmoiscripts/run_after_99-performance-summary.sh` with `VERBOSE=false`, and times repeated warm-path executions.

## Files in Scope
- `.chezmoiscripts/run_after_99-performance-summary.sh` — always-run script under benchmark
- `.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl` — recently improved adjacent hot path; keep validating it while iterating nearby warm-path work

## Off Limits
- Benchmark cheating: do not weaken the unsupported-host or no-marker semantics just to make the benchmark faster.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.
- Big script architecture changes (dispatcher/consolidation) that should be plan-first work.

## Constraints
- Keep changes minimal and low risk.
- Preserve current summary behavior and default non-verbose output.
- Prefer structural hot-path simplifications over shell micro-optimizations with no clear behavior-preserving rationale.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the benchmark; improve the real warm path for principled reasons.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog: tracked Claude defaults are safer, docs and health checks are aligned, and Codex skill metadata now front-loads the key jj/read-first cues.
- The remaining backlog items are harder by nature: broader Claude Bash allowlist reductions need workflow evidence, while warm-apply speedups need behavior-preserving script simplification.
- Kept in the latest segment: `run_after_38-setup-pi-maintenance-agent.sh.tmpl` is now materially cheaper on unsupported hosts with no opt-in marker because the script delays later-path setup and avoids spawning `rm` when no Pi-agent state file exists.
- Current hypothesis: `run_after_99-performance-summary.sh` still pays avoidable default-path cost because it keeps verbose-only helper setup and branch structure in the straight-line path even when `VERBOSE=false`, which is the normal warm-apply case.
