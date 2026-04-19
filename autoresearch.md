# Autoresearch: warm apply hot-path cleanup

## Objective
Find and implement minimal, low-risk improvements to the remaining always-run chezmoi scripts that still affect warm apply time.

The earlier Claude/docs/health-check/prompt gaps were closed in prior segments. The low-hanging prompt alignment work now looks mostly exhausted, so this segment returns to warm-apply performance. The first target is the no-op path for `.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl`: on unsupported hosts with no opt-in marker, the script should exit very cheaply because the Pi maintenance agent is intentionally inactive there.

## Metrics
- **Primary**: `total_us` (µs, lower is better) — total wall-clock time for repeatedly executing the rendered `run_after_38` script in a controlled unsupported-host/no-marker benchmark harness.
- **Secondary**:
  - `per_run_us` — average warm-path cost per script invocation
  - `loops` — benchmark iteration count used for the run

## How to Run
`./autoresearch.sh`

The script renders `.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl`, builds a temporary HOME with the shared helper library, simulates an unsupported host with no Pi-agent opt-in marker, and times repeated no-op executions.

## Files in Scope
- `.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl` — always-run script under benchmark
- `dot_local/private_lib/chezmoi-helpers.sh` — only if a tiny helper-facing simplification becomes clearly necessary for the hot path
- `.chezmoiscripts/run_after_99-performance-summary.sh` — adjacent always-run script, but only if `run_after_38` proves unproductive

## Off Limits
- Benchmark cheating: do not weaken the unsupported-host or no-marker semantics just to make the benchmark faster.
- Secret files, env files, machine-local private inputs, or unrelated bootstrap/tool version changes.
- Big script architecture changes (dispatcher/consolidation) that should be plan-first work.

## Constraints
- Keep changes minimal and low risk.
- Preserve current Pi maintenance agent behavior, including self-healing and explicit opt-in.
- Prefer structural hot-path simplifications over shell micro-optimizations with no clear behavior-preserving rationale.
- Validation must pass via `autoresearch.checks.sh`.
- Do not overfit to the benchmark; improve the real no-op path for principled reasons.

## What's Been Tried
- Earlier segments spent down the low-hanging agent-safety/prompt backlog: tracked Claude defaults are safer, docs and health checks are aligned, and Codex skill metadata now front-loads the key jj/read-first cues.
- The remaining backlog items are harder by nature: broader Claude Bash allowlist reductions need workflow evidence, while warm-apply speedups need behavior-preserving script simplification.
- Current hypothesis: `run_after_38-setup-pi-maintenance-agent.sh.tmpl` still pays avoidable setup cost on unsupported hosts with no opt-in marker because it defines many later-path functions and variables before the script can exit. Delaying those definitions until after the early gates should reduce warm-path cost without changing behavior.
