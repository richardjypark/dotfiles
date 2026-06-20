# Evaluation and Recovery

Reference for the `deli-auto-research` skill. Load when verifying findings or diagnosing liveness/recovery failures. The core protocol lives in `SKILL.md`; the verifier workflow is in its §10.

## 1. Evaluation Rules

1. The worker may self-check but may not self-approve.
2. The verifier must inspect artifacts and reproduce checks, not grade only the summary.
3. Every claimed source, citation, benchmark, or external fact must be traceable.
4. Verify citation-like records at least every 20 additions and at every generation boundary, whichever occurs first.
5. Rejected claims remain in run/eval history but never enter canonical findings.
6. Deterministic tests outrank LLM judgments.
7. A goal judge's `done` verdict controls continuation only; it is not evidence of correctness.
8. For model or strategy evaluation at scale, use `batch_runner.py` to collect isolated trajectories and add a task-specific grader. A completed trajectory only means the run terminated, not that its answer was correct.

## 2. Watchdog and Recovery Layers

| Layer | Mechanism | Depends on | Authorized actions |
|---|---|---|---|
| L0 | OS service manager for Hermes gateway | Host OS | Start/restart gateway; alert on repeated service failure |
| L1 | Kanban dispatcher | Gateway | Reclaim crashed/stale workers, enforce max runtime, retry, circuit-break |
| L2 | No-agent diagnostic cron | Gateway cron | Read diagnostics and state timestamps; append watchdog log; alert only |
| L3 | LLM supervisor cron | Gateway cron + model provider | Reconcile board, create/link successor cards, apply stall/pivot policy |
| L4 | Worker heartbeat | Running worker | Call `kanban_heartbeat`; expose progress and prevent false stale reclaim |

Worker requirements:

- heartbeat at meaningful milestones;
- for operations longer than one hour, heartbeat at least hourly (the dispatcher reclaims tasks running past `kanban.dispatch_stale_timeout_seconds` — 4h default — with no heartbeat in the last hour);
- never fake a heartbeat after work has stopped;
- never use a watchdog to modify findings or impersonate a worker report.

Recovery policy:

- transient crash: allow the dispatcher retry budget;
- stale worker: reclaim and requeue without counting it as cognitive progress;
- protocol violation: inspect the card body and worker skill; create a corrected successor;
- provider/auth/rate-limit failure: preserve evidence, avoid respawn storms, and retry only after the condition changes;
- external dependency: block with a complete report and configured notification; continue unrelated cards;
- dead gateway: OS service manager restarts it; cron cannot perform this recovery while the gateway is down.
