# Execution Plans

Use `plans/YYYY-MM-DD-<slug>.md` for changes that need durable reasoning beyond chat history.

## Create A Plan Before Mutating The Repo When

- the task spans multiple subsystems,
- the task touches bootstrap, hardening, version pins, externals, or agent operating docs,
- the implementation is likely to take multiple iterations,
- or important design decisions are still being made.

## Default File Shape

```md
# <Title>

## Goal

## Success Criteria

## Findings

## Decisions

## Implementation Steps

## Validation

## Status
```

Keep the plan decision-complete. Update it when assumptions change, when new constraints are discovered, and when a step is finished.

## Retention

- Keep the plan in the final change when the work is high-impact, spans multiple sessions, or explains repo structure that future agents will need.
- Remove one-off scratch plans before finishing when the important decisions have been folded into the code, docs, or commit message.
