# Execution Plans

Use `plans/YYYY-MM-DD-<slug>.md` for local scratch planning when a change needs reasoning beyond chat history.

## Create A Plan Before Mutating The Repo When

- the task spans multiple subsystems,
- the task touches bootstrap, hardening, version pins, externals, or agent operating docs,
- the implementation is likely to take multiple iterations,
- or important design decisions are still being made.

## Git Policy

- Dated plan files under `plans/` are local development scratch notes.
- Do not commit dated plan files.
- `.gitignore` should ignore `plans/[0-9]*.md` so scratch plans stay out of Git history.
- `plans/README.md` may remain tracked as the convention document.

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

- Remove dated scratch plans before finishing if they were accidentally added to the index.
- Fold any lasting decisions into code comments, docs, or commit messages instead of keeping the scratch plan tracked.
