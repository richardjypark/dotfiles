# Execution Plans

Use `plans/` for local-only planning artifacts when a change needs reasoning beyond chat history.

For substantial work, the canonical Codex workflow is:

1. Deep-read the relevant repo surfaces before proposing changes.
2. Write `plans/YYYY-MM-DD-<slug>-research.md` with findings and constraints.
3. Write `plans/YYYY-MM-DD-<slug>-plan.md` with the implementation approach.
4. Review and annotate the plan.
5. Revise the plan until it is decision-complete.
6. Do not implement until the user explicitly approves the plan.
7. During implementation, update the plan status or todo list as work completes.

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

## Default Artifact Set

```md
# YYYY-MM-DD-<slug>-research.md

## Goal
## Findings
## Constraints
## Risks
## Open Questions
```

```md
# YYYY-MM-DD-<slug>-plan.md

## Goal
## Success Criteria
## Decisions
## Implementation Steps
## Validation
## Rollback / Failure Handling
## Status
```

## Annotation Cycle

- Review the plan in an editor, not just in chat.
- Add inline notes where assumptions, constraints, or tradeoffs need correction.
- Send the agent back to the document to address those notes.
- Repeat until the plan is decision-complete.
- Use an explicit guard like `don't implement yet` until approval is given.

## Legacy Single-File Plans

`plans/YYYY-MM-DD-<slug>.md` remains acceptable for quick local notes or very small multi-step tasks. Use the paired `*-research.md` and `*-plan.md` artifacts by default for high-impact work.

## Plan Completion Tracking

- Add a granular todo list to the plan before implementation when the work will span multiple phases.
- Mark tasks or phases as completed in the plan during implementation so the plan remains the progress surface.
- Keep lasting design decisions in docs, code comments, or commits rather than relying on old scratch plans.

Keep the plan decision-complete. Update it when assumptions change, when new constraints are discovered, and when a step is finished.

## Retention

- Remove dated scratch plans before finishing if they were accidentally added to the index.
- Fold any lasting decisions into code comments, docs, or commit messages instead of keeping the scratch plan tracked.
