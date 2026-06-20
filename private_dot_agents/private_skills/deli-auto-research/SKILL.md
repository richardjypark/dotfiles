---
name: deli-auto-research
description: Hermes-native protocol for unattended, long-horizon research and engineering. Uses durable Kanban task graphs, fresh cron supervisors, bounded goal loops, delegated leaf agents, independent verification, stall-aware pivots, and layered watchdogs.
version: 2.2.1
platforms: [linux, macos]
metadata:
  hermes:
    tags: [research, autonomous, long-horizon, orchestration, kanban, delegation, evaluation, watchdog, anti-loop]
    category: research
    related_skills: [kanban-worker, kanban-orchestrator]
    config:
      - key: deli_autoresearch.task_root
        description: Absolute root directory for Deli AutoResearch projects
        default: "~/deli-auto-research"
        prompt: "Root directory for autonomous research projects"
      - key: deli_autoresearch.supervisor_schedule
        description: Cadence for the fresh-session supervisor cron job
        default: "every 2h"
        prompt: "Supervisor schedule"
      - key: deli_autoresearch.stall_generations
        description: Consecutive no-progress generations before a structural pivot is mandatory
        default: 2
        prompt: "Generations before forced pivot"
      - key: deli_autoresearch.max_parallel
        description: Maximum parallel research workers per generation
        default: 3
        prompt: "Maximum parallel workers"
      - key: deli_autoresearch.goal_max_turns
        description: Default goal-loop turn budget for a complex Kanban card
        default: 15
        prompt: "Goal-loop turn budget"
      - key: deli_autoresearch.task_max_runtime
        description: Default wall-clock limit for an ordinary worker card
        default: "30m"
        prompt: "Worker card runtime limit"
---

# Deli AutoResearch — Hermes Native

Deli AutoResearch is a protocol for autonomous projects that run for hours, days, or weeks without depending on one conversation remaining alive. It treats a long-horizon project as a sequence of bounded, auditable worker runs coordinated by Hermes Kanban and supervised by fresh cron sessions.

This is a protocol skill. It ships no required executable code. During setup, Hermes may generate local helper scripts under `~/.hermes/scripts/` — a deterministic watchdog and, for indefinite projects, a supervisor pre-check — when deterministic health checks are useful.

Detailed matrices live in `references/` and load on demand (see Reference Material at the end). Keep this core file as the operating contract; pull a reference file in with `skill_view("deli-auto-research", "<path>")` when its phase begins.

The examples below use the configured defaults from `deli_autoresearch.*`. During bootstrap, resolve those values once, record them in `state/task_spec.md`, and use the resolved values instead of hard-coded literals when a project overrides the defaults.

## 1. When to Use

Use this skill when the task:

- requires repeated research, experiments, writing, coding, or verification across many agent turns;
- benefits from parallel specialists, independent review, or durable handoffs;
- must survive an interrupted chat, context compaction, a worker crash, or a machine restart;
- has measurable acceptance criteria and can persist artifacts to a project directory.

Do not use it for a one-turn answer, a single deterministic command, or a short subtask that can be completed directly. Use `delegate_task` for a temporary reasoning fork, `execute_code` for mechanical tool pipelines, and `terminal(background=true)` for one long-running process.

## 2. Core Invariants

1. **The current chat is not the control plane.** Durable work lives in Kanban, cron, the gateway service, and project files.
2. **Execution state and domain state are separate.** Kanban owns task status, attempts, dependencies, heartbeats, retries, and handoffs. Project files own the research specification, verified findings, metrics, and direction history.
3. **Long horizon means many bounded runs.** Do not keep one giant conversation alive for days. Cron supervisors and Kanban worker attempts start fresh sessions.
4. **Goal mode is a bounded inner loop, not the project loop.** `/goal` and Kanban `--goal` continue within the same session and are reserved for one well-scoped card.
5. **A completion judge is not a truth judge.** Goal completion never substitutes for tests, source checking, reproduction, or an independent verifier card.
6. **Parallel workers never share canonical writes.** Each worker writes only to its task-scoped run directory. A verifier evaluates; a synthesizer is the sole writer of canonical findings.
7. **Liveness is not progress.** Heartbeats prove that a process is alive. Only verified metric deltas count as progress.
8. **Every autonomous create is idempotent.** Use a stable idempotency key derived from project, generation, role, and direction.
9. **Routine work needs no confirmation.** Execute preparation, submission, repair, resubmission, validation, and monitoring when they are within the pre-authorized task scope.
10. **Unsafe or externally blocked work does not guess.** Record the blocker with `kanban_block`, notify through the configured delivery path, and continue independent safe workstreams.

### Invocation Modes

Choose the mode before doing any work:

- **Kanban worker mode:** if `HERMES_KANBAN_TASK` is set, immediately call `kanban_show()`, then follow the Worker, Verifier, or Synthesizer protocol encoded in the card. Do not initialize a second project or create an unrelated graph.
- **Supervisor mode:** if the invocation is a scheduled supervisor run or the request is to continue an existing project, read the project state and board, reconcile them, and create only the next idempotent graph. Do not perform domain work.
- **Bootstrap mode:** if no initialized project exists, create the task specification and state tree, discover real profiles, seed the first durable graph, and register the supervisor/watchdog from the current non-cron session.
- **Interactive inspection mode:** when asked for status, report from Kanban plus verified project state. Do not infer progress from chat history or heartbeat activity.

During an authorized unattended run, resolve ordinary ambiguity from the task specification and log the decision. Block rather than guess only when safety, credentials, destructive scope, legal authority, payment, publication, or another explicitly reserved decision is required.

## 3. Hermes Primitive Map

| Primitive | Use in this protocol | Do not use it for |
|---|---|---|
| Kanban task graph | Durable work units, retries, dependencies, named profiles, audit trail | A tiny answer needed immediately by the parent |
| `hermes kanban swarm` | Standard fan-out → verifier → synthesizer topology | Highly custom iterative graphs that need per-card policies |
| Kanban goal mode | Bounded "keep working until these card criteria are met" loop | Days-to-weeks orchestration or factual verification by itself |
| `delegate_task` | Synchronous fresh-context reasoning, usually 1–3 independent leaf tasks | Durable jobs, watchdogs, or work that must outlive the parent turn |
| `cronjob` | Recurring fresh-session supervisor and scheduled reviews | Recursive creation of more cron jobs from inside a cron run |
| No-agent cron | Cheap deterministic diagnostics and alerts | Detecting a dead gateway; the cron scheduler itself depends on the gateway |
| `terminal(background=true)` + `process` | Long builds, experiments, servers, or external commands inside a card | A durable multi-agent queue |
| `execute_code` | Parsing, deduplication, scoring, metric computation, and deterministic fan-in | Reasoning-heavy research or interactive/background processes |
| `/background` | Optional ad hoc side investigation from an interactive session | Canonical state, durable orchestration, or required parent handoff |
| `batch_runner.py` | Offline strategy/model evaluation over a standardized prompt set | The live project controller or a correctness grader without a task-specific scorer |

## 4. Runtime Architecture

```text
OS service manager
└── Hermes gateway
    ├── cron scheduler
    │   ├── deterministic watchdog job       fresh script invocation
    │   └── LLM supervisor job               fresh AIAgent session each tick
    │
    └── Kanban dispatcher
        └── project board / task graph
            ├── exploration worker A          fresh worker process
            ├── exploration worker B          fresh worker process
            ├── refutation worker C           fresh worker process
            └── verifier                      waits for all workers
                └── synthesizer               waits for verifier approval
                    └── canonical project state
```

Inside one worker card, Hermes may use:

```text
worker AIAgent
├── delegate_task(tasks=[...])        temporary fork/join, final summaries only
└── terminal(background=true)         long command
    └── process(poll|wait|log|kill)   command lifecycle
```

The OS service manager is the only layer independent of the Hermes gateway. Gateway cron cannot detect that the gateway itself is dead.

## 5. Role Separation

Use named Hermes profiles and keep their permissions narrow.

| Role | Responsibilities | Forbidden behavior |
|---|---|---|
| Orchestrator / supervisor | Inspect state and board, create/link cards, detect stalls, choose pivots, unblock only with evidence | Performing the research or editing canonical findings |
| Worker | Execute one assigned direction, produce evidence and task-scoped artifacts, heartbeat, complete or block | Editing `progress.json`, canonical findings, or unrelated cards |
| Verifier | Reproduce checks, challenge claims, score evidence, write eval records | Repairing the worker's result while pretending it passed |
| Synthesizer | Promote only verifier-approved outputs into canonical state | Accepting unsupported claims or changing task policy |
| Watchdog | Read liveness/diagnostics and alert; OS layer may restart the gateway | Reading research content, editing findings, or inventing a new direction |

For best enforcement, give the orchestrator profile the `kanban` control surface and little or no implementation tooling. Give workers only the tools required by their task. Keep `delegation.max_spawn_depth` at `1` unless nested orchestration is explicitly required.

## 6. Project State

Use one preserved absolute project directory. For research tasks, assign cards a shared `dir:/absolute/project/path` workspace, but require each worker to write below its own task ID.

```text
{project}/
├── state/
│   ├── task_spec.md             immutable goal, scope, milestones, metrics, acceptance tests
│   ├── progress.json            supervisor-owned current state; atomic replace
│   ├── directions.jsonl         supervisor-owned direction and pivot history
│   ├── findings.jsonl           synthesizer-owned verified findings only
│   ├── evals.jsonl              verifier-owned evaluation records
│   └── generation_log.jsonl     supervisor-owned generation transitions
├── runs/
│   └── {kanban_task_id}/
│       ├── notes.md
│       ├── evidence.jsonl
│       ├── validation.json
│       └── artifacts/
└── logs/
    ├── supervisor.jsonl
    └── watchdog.jsonl
```

### Ownership Rules

- Parallel workers may not append to the same central JSONL file.
- Workers create `runs/$HERMES_KANBAN_TASK/` and write only there.
- The verifier appends one evaluation record after all parent workers finish.
- The synthesizer is the only process that appends to `findings.jsonl`.
- The supervisor is the only process that replaces `progress.json` or appends directions and generation transitions. These are derived program metrics and caches; Kanban remains authoritative for task lifecycle state.
- The supervisor pre-check (when attached) owns only the `last_supervisor_check_at` field and may atomically update it on every tick, including suppressed ticks.
- Replace JSON atomically: write a temporary file, validate it, then rename it.
- Serialize all writes to shared project state (`progress.json`, central JSONL files, and shared logs) with a project-local lock such as `state/.deli-state.lock` via `flock`. A later supervisor run that cannot acquire the lock must no-op or reschedule instead of interleaving graph creation.
- Use UTC RFC 3339 timestamps.

### `progress.json` Minimum Schema

```json
{
  "schema_version": 3,
  "project_id": "example-project",
  "status": "running",
  "generation": 1,
  "primary_metric": {"name": "verified_coverage", "value": 0.35, "target": 0.90},
  "verified_findings": 12,
  "stale_count": 0,
  "active_task_ids": [],
  "blocked_task_ids": [],
  "last_supervisor_at": null,
  "last_supervisor_check_at": null,
  "last_verified_progress_at": null,
  "next_action": "seed_generation_1"
}
```

`status` is one of `running`, `paused`, `blocked`, or `complete`. `last_supervisor_at` advances only when the supervisor session actually reconciles; `last_supervisor_check_at` advances every supervisor tick (set by the pre-check, or by the session itself when no pre-check is attached) and is the timestamp the watchdog reads for liveness.

### Append-Only Record Shapes

A direction record must identify structural dimensions, not only a prose label:

```json
{"ts":"...","generation":2,"direction_id":"g2-d1","hypothesis":"...","method":"...","evidence_source":"...","representation":"...","objective":"...","novelty_against":["g1-d1"],"status":"queued"}
```

A verified finding must retain its evidence and verifier:

```json
{"ts":"...","finding_id":"f-0012","generation":2,"claim":"...","evidence":["runs/t_x/evidence.jsonl#L4"],"source_urls":[],"confidence":0.82,"verifier_task_id":"t_verify","status":"verified"}
```

All logs use:

```json
{"ts":"...","source":"supervisor|worker|verifier|synthesizer|watchdog","level":"info|warn|error|decision","event":"...","detail":"..."}
```

## 7. Task Specification

Before dispatching work, `state/task_spec.md` must contain:

1. Objective and non-objectives.
2. Deliverables and file locations.
3. Explicit completion criteria.
4. A primary progress metric and optional secondary metrics.
5. Validation commands or evidence standards.
6. Citation/source rules.
7. Authorized external actions and destructive-action boundaries.
8. Runtime, cost, file-size, and concurrency limits.
9. Known external dependencies and escalation route.
10. Conditions that require blocking rather than guessing.

A vague objective such as "research this thoroughly" is invalid. Convert it into measurable criteria before starting workers.

## 8. Initialization Procedure

### Step 1 — Establish the Durable Control Plane

Initialize Kanban and run the gateway under host supervision:

```bash
hermes kanban init
hermes gateway install
hermes gateway start
```

On a server that needs boot-time supervision, install the appropriate system service. Do not rely on an open terminal or an interactive Hermes session to keep the dispatcher alive.

### Step 2 — Discover Real Profiles

Before assigning cards, inspect the profiles known to the board:

```bash
hermes kanban assignees --json
```

Never invent an assignee name. Ensure worker profiles can load the bundled `kanban-worker` skill. Ensure the orchestrator profile can load `kanban-orchestrator` and has access to the `kanban` toolset.

If a card is created with `--skill deli-auto-research`, this skill must be installed in that assignee profile. Otherwise omit the skill pin and put the complete worker contract in the card body.

### Step 3 — Create the Project State

Create the directory tree, write `task_spec.md`, initialize `progress.json`, and append the initial direction records. Resolve all configured paths to absolute paths before creating tasks or cron jobs.

### Step 4 — Seed a Durable Graph

For a standard topology, use the swarm helper after configuring a suitable board default workspace. Cap the worker list at the resolved `deli_autoresearch.max_parallel` and at the number of real available worker profiles; if a graph would exceed capacity, queue fewer directions rather than oversubscribing profiles:

```bash
hermes kanban swarm "<project goal and acceptance criteria>" \
  --workers <explorer-profile>,<alternative-profile>,<refuter-profile> \
  --verifier <verifier-profile> \
  --synthesizer <synthesizer-profile>
```

When the helper in the installed Hermes version cannot expose deterministic idempotency keys for every generated worker, verifier, and synthesizer card, prefer explicit card creation for unattended projects.

For per-card policies, create an explicit graph. Each worker card should normally include:

```bash
hermes kanban create "G1-D1: <verifiable direction>" \
  --body "<self-contained context, deliverable, evidence standard, and completion criteria>" \
  --assignee <real-profile> \
  --workspace dir:/absolute/project/path \
  --goal \
  --goal-max-turns <resolved-goal-max-turns> \
  --max-runtime <resolved-task-max-runtime> \
  --max-retries 2 \
  --idempotency-key "<project-id>:g1:worker:g1-d1"
```

Create the verifier with every worker task as a parent. Create the synthesizer with the verifier as its parent. Parent gating, not polling prose, controls the fan-in. Use the canonical idempotency shape `<project-id>:g<generation>:<role>:<direction-id>` for workers, verifier cards, synthesizer cards, repair cards, and successors.

### Step 5 — Register the Fresh-Session Supervisor

Create the recurring supervisor from the orchestrator profile. The prompt must be self-contained because every cron tick starts a fresh session.

```text
cronjob(
  action="create",
  name="deli-supervisor-<project>",
  schedule="<resolved-supervisor-schedule>",
  workdir="/absolute/project/path",
  skills=["deli-auto-research"],
  enabled_toolsets=["terminal", "file", "kanban", "code_execution"],
  deliver="local",
  prompt="Act only as the Deli supervisor for this project. First atomically update the `last_supervisor_at` field in `state/progress.json` and append a supervisor log. Read task_spec.md, progress.json, directions.jsonl, evals.jsonl, and the Kanban board. Do not perform research. Reconcile task states, calculate verified metric deltas, detect stalls, create the next idempotent task graph or a structural pivot when required, and leave a durable log. Do not ask questions. Block and report only when the specification requires human authority."
)
```

A cron-run agent must not create or manage more cron jobs. Install all recurring jobs during initialization from an interactive or setup session.

For indefinite projects, gate the model wake with a deterministic pre-check attached to the same cron job via the `script` field (`script="deli-supervisor-precheck.py"`, generated under `~/.hermes/scripts/`). The pre-check must:

- always atomically stamp `state/progress.json.last_supervisor_check_at` and append a cheap liveness log line, **even on suppressed ticks**;
- emit `{"wakeAgent": false}` when `progress.json.status` is `complete` or `paused`, or when no domain state changed since the previous tick;
- otherwise emit `{"wakeAgent": true}` so the supervisor session runs.

Define "domain state changed" deterministically, for example by persisting and comparing a compact tuple of board status counts, active/blocked task IDs, latest eval/finding/generation-log mtimes or hashes, and the current `progress.json.generation`/`next_action`. Do not include `last_supervisor_check_at` itself in the comparator or every tick will wake the model.

This keeps a `$0` liveness signal flowing to the watchdog while still suppressing unnecessary model calls. Never let the pre-check suppress a wake without first updating `last_supervisor_check_at`; otherwise the watchdog in Step 6 will false-alarm on a healthy, idle project.

### Step 6 — Register a Deterministic Watchdog

Generate a Python or Bash script in `~/.hermes/scripts/` that performs read-only checks and emits output only on failure. Its contract is:

- run `hermes kanban diagnostics --json`;
- inspect board counts and recent terminal events;
- detect blocked, `gave_up`, repeatedly timed-out, or ready-but-never-dispatched tasks;
- detect a supervisor liveness signal (`last_supervisor_check_at`, or `last_supervisor_at` when no pre-check is attached) older than three supervisor intervals, **unless** `progress.json.status` is `complete` or `paused`;
- append a watchdog log;
- print one actionable alert on failure and print nothing when healthy;
- never edit research state, change a direction, or approve a finding.

Schedule it in no-agent mode:

```bash
hermes cron create "every 15m" \
  --no-agent \
  --script deli-watchdog.py \
  --deliver <configured-alert-target> \
  --name "deli-watchdog-<project>"
```

This watchdog depends on the gateway scheduler. Host-level gateway supervision remains mandatory. The full layered recovery model (L0–L4) is in `references/evaluation-and-recovery.md`.

## 9. Worker Protocol

Every Kanban worker follows this order.

### 9.1 Start Correctly

1. Call `kanban_show()` to load the card, parent handoffs, comments, and previous attempts.
2. Call `kanban_heartbeat(note="started; loading project state")`.
3. Change to `$HERMES_KANBAN_WORKSPACE`.
4. Create `runs/$HERMES_KANBAN_TASK/`.
5. Read `task_spec.md`, the current progress snapshot, and only the direction history needed to avoid duplication.

Do not rely on the parent chat or undocumented context.

### 9.2 Execute One Direction

Work only on the assigned hypothesis/method. Do not silently broaden scope. Record major choices in the task run notes with `level=decision` equivalents.

Use batch delegation only when branches are independent and the parent needs all results before completing:

```text
delegate_task(tasks=[
  {"goal": "Investigate the strongest supporting case", "context": "<full project and card context>", "toolsets": ["web", "file"]},
  {"goal": "Try to falsify the same claim", "context": "<full project and card context>", "toolsets": ["web", "file"]},
  {"goal": "Find a structurally different analogy or method", "context": "<full project and card context>", "toolsets": ["web", "file"]}
])
```

Rules for delegated children:

- Default to leaf agents and flat delegation.
- Keep the batch at or below the configured concurrency, normally three.
- Include every path, constraint, error, deliverable, and validation rule in `context`.
- Children return summaries; they do not own durable project state.
- Parallel children must not edit the same file.
- Never use delegation for work that must survive interruption.

Budgets for the goal loop, delegation tree, and generation loop are summarized in `references/loops-stalls-and-pivots.md`.

### 9.3 Manage Long Commands

For a build, experiment, crawler, or server that exceeds a normal tool timeout:

```text
terminal(command="<command>", background=true, notify_on_complete=true)
process(action="poll", session_id="<returned-id>")
process(action="log", session_id="<returned-id>")
process(action="wait", session_id="<returned-id>")
```

Retain the process session ID in the run notes. Heartbeat while waiting, at least every 30–45 minutes and before any configured stale-worker threshold. Bound waits by the card's remaining runtime budget; if the budget is exhausted, stop the process with `process(action="kill")`, record the exit or kill reason, and block or complete according to the card criteria. Do not mark the card complete until results are materialized and validated. For jobs longer than the card runtime, use an external scheduler and a separate durable monitor card rather than abandoning an untracked process.

### 9.4 Produce Evidence

Before completion:

- run the specified validation commands;
- record exact commands, exit codes, relevant output, and source identifiers;
- separate observations from interpretations;
- record negative and contradictory results;
- write artifacts only under the task run directory;
- summarize residual risk.

### 9.5 Terminate Through Kanban

Complete with a structured handoff:

```text
kanban_complete(
  summary="<what was done and the verified result>",
  metadata={
    "direction_id": "g1-d1",
    "run_dir": "runs/<task-id>",
    "changed_files": [],
    "verification": ["<exact command or evidence procedure>"],
    "metric_candidate": {"name": "...", "value": 0.0},
    "dependencies": [],
    "blocked_reason": null,
    "retry_notes": "",
    "residual_risk": []
  }
)
```

If blocked, call `kanban_block(reason="<specific blocker, attempts, evidence, and required authority>")`.

A plain final response without `kanban_complete` or `kanban_block` is a protocol failure: the dispatcher emits a `protocol_violation` event and auto-blocks the card instead of respawning it.

## 10. Verifier Protocol

The verifier is authoritative for acceptance, not the worker and not the goal judge.

1. Call `kanban_show()` and read every parent handoff.
2. Re-open the task-scoped artifacts; do not trust summaries alone.
3. Re-run deterministic checks where possible.
4. Reacquire a sample of external sources independently.
5. Attempt at least one falsification, boundary case, or contradictory interpretation.
6. Check that claimed metric changes follow from evidence rather than activity counts.
7. Append one `evals.jsonl` record.
8. Pass only when every mandatory criterion is supported.

Minimum evaluation record:

```json
{"ts":"...","generation":1,"verifier_task_id":"t_verify","verdict":"pass|repair|reject","metric_delta":{"name":"verified_coverage","before":0.35,"after":0.47},"checks":[{"name":"source_recheck","result":"pass"}],"unsupported_claims":[],"required_repairs":[],"residual_risk":[]}
```

On failure, block the verifier card with exact repair requirements. Because the synthesizer depends on the verifier, it must not run until the verifier completes successfully.

Full evaluation rules — citation-recheck cadence, deterministic-test precedence, and batch-eval grading — are in `references/evaluation-and-recovery.md`.

## 11. Synthesizer Protocol

After verifier approval:

1. Read the verifier's eval record and parent handoffs.
2. Promote only approved claims into `findings.jsonl`.
3. Deduplicate against existing verified findings.
4. Update derived artifacts or drafts.
5. Record provenance back to worker and verifier task IDs.
6. Complete with a structured summary and metric delta.

The synthesizer does not choose the next direction. The next supervisor tick updates progress and creates the next generation.

## 12. Supervisor Protocol

Every supervisor cron tick is a fresh session and follows this state machine.

### 12.1 Report Alive First

When the supervisor session runs, atomically set `last_supervisor_at` (the pre-check has already stamped `last_supervisor_check_at` for this tick), append `supervisor_started`, then inspect the board. A failed state write is itself an alert condition.

### 12.2 Reconcile the Board

Classify every project card:

- **Running with fresh heartbeat:** leave it alone.
- **Ready/todo with satisfied parents:** allow the dispatcher to handle it; optionally trigger one dispatch pass if the gateway is healthy.
- **Blocked by missing authority or external dependency:** preserve the block, report it, and continue independent cards.
- **Crashed/timed out:** inspect `hermes kanban runs <id>` and logs before deciding whether to retry.
- **Repeated failure or protocol violation:** do not blindly unblock. Create a better-scoped successor with the failure evidence and a new idempotency key.
- **Done:** consume the structured handoff; never infer progress from status alone.

### 12.3 Close a Generation

A generation closes only when its verifier and synthesizer have completed. Then:

1. compute the verified metric delta;
2. update `progress.json` atomically;
3. reconcile `active_task_ids` and `blocked_task_ids` from the board, then update the direction record status;
4. append a generation transition;
5. decide complete, continue, repair, or pivot — apply the stall and forced-pivot policy in `references/loops-stalls-and-pivots.md`.

Use `execute_code` for deterministic JSONL parsing, deduplication, and metric calculations when it reduces context and error risk.

### 12.4 Create the Next Graph Idempotently

Before creating a card, check both `progress.json.active_task_ids` and the Kanban board. Use keys such as:

```text
<project-id>:g<generation>:<role>:<direction-id>
```

Never create two active cards with the same logical key.

### 12.5 Completion

When every task-spec criterion is independently verified:

- set `progress.json.status` to `complete`;
- write a final generation log with exact evidence pointers;
- ensure no unfinished child cards remain;
- allow the supervisor pre-check to suppress future LLM wakes;
- deliver the final report through the configured channel.

## 13. Completion Checklist

The project is complete only when all are true:

- every success criterion in `task_spec.md` is satisfied;
- the primary metric meets its target or an explicitly authorized terminal condition;
- all canonical findings have evidence and verifier IDs;
- required tests, builds, reproductions, and source checks pass;
- unresolved risks are documented;
- no required card remains `todo`, `ready`, `running`, or blocked without an accepted disposition;
- `progress.json.status` is `complete`;
- a final report identifies deliverables, exact validation evidence, limitations, and remaining optional work.

## Reference Material

Load these with `skill_view("deli-auto-research", "<path>")` when the relevant phase begins:

- `references/loops-stalls-and-pivots.md` — the four loop types and their budgets, operational vs. cognitive stall detection, and the forced-pivot policy. Load before deciding whether a generation made progress or how to pivot.
- `references/evaluation-and-recovery.md` — verifier evaluation rules, citation-recheck cadence, and the L0–L4 watchdog/recovery layering. Load when verifying findings or diagnosing liveness failures.
- `references/engineering-and-limits.md` — engineering constraints for worker cards, plus the system limits and historical provenance of this protocol. Load before writing code or assessing what the protocol cannot guarantee.
