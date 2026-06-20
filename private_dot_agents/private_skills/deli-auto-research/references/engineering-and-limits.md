# Engineering Constraints, Limits, and Provenance

Reference for the `deli-auto-research` skill. Load before writing code in a worker card, or when assessing what the protocol can and cannot guarantee. The core protocol lives in `SKILL.md`.

## 1. Engineering Constraints

1. Ordinary worker cards touch at most five large files; no generated source file should exceed 300 lines without an explicit task-spec exception.
2. Parallel workers use disjoint run directories or separate Git worktrees.
3. Validation runs before every worker completion and after every synthesis.
4. Use `worktree` workspaces for parallel code edits; use preserved `dir:` workspaces for research artifacts.
5. Keep raw logs out of Kanban metadata. Store paths, concise summaries, checks, and residual risks.
6. Do not put credentials, tokens, or secret-bearing output in task comments, metadata, or project logs.
7. Prefer diversity across directions over repeatedly deepening one failing frame.
8. Keep long raw evidence in files; keep Kanban handoffs concise and structured.
9. Never use `/resume` as the durability mechanism. Files and Kanban are authoritative. Goal mode inside a bounded card is the only intentional same-session continuation.
10. Do not use `/background` for required work whose result must update project state.

## 2. Limits and Provenance

- Hermes Kanban is a single-host system. Multi-host coordination requires an external queue or separate boards bridged deliberately.
- Cron and the Kanban dispatcher share the gateway dependency. A cron watchdog is not an independent gateway watchdog.
- `delegate_task` is synchronous and non-durable; interrupting the parent can cancel its children.
- Goal loops can encourage persistence but can also repeat a weak frame. The supervisor's generation boundary and structural pivot policy are the anti-loop mechanism.
- LLMs can fabricate citations, data, and success claims. This protocol makes external checks mandatory but cannot remove the underlying error source.
- Separation of duties is strongest when enforced with profile tool restrictions and file ownership; prose instructions alone are weaker.

The predecessor protocol reported the following author-supplied paper outcomes. They are retained only as historical provenance and do not constitute external validation of this Hermes-native revision:

| Paper | Pages | Citations | In-framework self-rating |
|---|---:|---:|---:|
| Autonomous Research Agents | 59 | 228 | 8.0/10 |
| Continual Learning | 65 | 326 | 8.0/10 |
| Long-Horizon Decision-Making | 55 | 384 | 8.0/10 |
| Self-Play (285B RL experiment + theory hardening) | 75 | 217 | 8.6/10 |

The predecessor also reported a longest continuous run of 72 hours with six directional human inputs and no operational intervention. Treat this as a historical project claim, not a benchmark guarantee.
