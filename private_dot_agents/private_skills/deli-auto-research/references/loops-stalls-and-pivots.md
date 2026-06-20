# Loops, Stalls, and Pivots

Reference for the `deli-auto-research` skill. Load when deciding whether a generation made real progress, or how to pivot after a stall. The core protocol lives in `SKILL.md`.

## 1. Loop Semantics and Budgets

Deli uses four distinct loops. Do not conflate them.

| Loop | Unit | Default bound | Purpose |
|---|---|---|---|
| AIAgent tool loop | Model/tool iteration inside one turn | Agent configuration | Execute a single turn |
| Kanban goal loop | Complete agent turns within one card | 15 (this protocol; Hermes' own default is 20 via `goals.max_turns`) | Persist on one scoped acceptance criterion |
| Delegation tree | Child agent runs inside the parent turn | 3 concurrent, depth 1 | Fresh-context parallel reasoning |
| Research generation loop | Fresh Kanban graph per generation | Task-spec and stall policy | Long-horizon progress |

Recommended ordinary card limits:

- `--goal-max-turns 15` (this protocol pins 15 for tighter cards; Hermes accepts any positive integer up to `goals.max_turns`);
- `--max-runtime 30m`;
- `--max-retries 2`;
- no more than three parallel workers;
- one active task per slow/rate-limited profile when resources are constrained.

A goal loop uses the same session and its judge sees the agent's latest final response, not the complete world state. Require exact evidence in the card body and treat verifier approval as the real gate.

If a goal card exhausts its turn budget, let it block. The supervisor should inspect why and create a smaller or structurally different successor rather than repeatedly resuming the same loop.

## 2. Stall Detection

Separate operational stalls from cognitive stalls.

| Condition | Classification | Action |
|---|---|---|
| Worker exceeds stale timeout and has no recent heartbeat | Operational liveness failure | Let dispatcher terminate/reclaim and requeue; inspect run history |
| Project incomplete, no running/ready work, no intentional block | Orchestration gap | Supervisor creates the next idempotent graph |
| Completed generation adds no verified finding, metric gain, uncertainty reduction, or eliminated hypothesis | Cognitive stall | `stale_count += 1` |
| Primary verified metric regresses | Regression | `stale_count += 1`; create reproduction/refutation card |
| Same failure repeats after retry | Structural task defect | Block old card; create revised successor, not another blind retry |

Activity does not reset staleness. New files, more tokens, more citations, or longer prose are not progress unless the verifier accepts a meaningful delta.

## 3. Forced Pivot Policy

- `stale_count == 0`: continue the most promising diverse directions.
- `stale_count == 1`: add an explicit refutation or reproduction direction.
- `stale_count >= 2`: mandatory structural pivot.
- `stale_count >= 4`: block the project control card, issue an alert with a full evidence report, and continue only independent pre-authorized lines.

A structural pivot must change at least two of these dimensions relative to prior failed directions:

1. hypothesis or decomposition;
2. evidence source or dataset;
3. method or toolchain;
4. representation or abstraction level;
5. optimization objective or success metric;
6. environment or execution constraint.

Valid perturbations include reversing a key assumption, reproducing a baseline, changing source class, moving from synthesis to falsification, decomposing at a different scale, or testing an external constraint directly.

Changing only temperature, prompt wording, search keywords, or a small parameter is tactical tuning, not a structural pivot.
