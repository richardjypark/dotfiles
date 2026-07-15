# Skill Routing Eval

> **Repository-only documentation:** this file and the eval implementation are
> excluded by `.chezmoiignore`. They are development tools for this source repo
> and must not render into managed home directories.

## The idea in plain English

Each skill has a short label: its frontmatter `name` and `description`. Before an
agent can follow the full skill, it first has to choose the right label for the
user's request. This eval checks that first decision.

Think of it as a librarian choosing the correct manual:

```text
User request
     |
     v
+------------------------+
| Names + descriptions   |
| from current SKILL.md  |
+-----------+------------+
            |
            v
+------------------------+
| Hermes chooses one     |
| skill, or chooses none |
+-----------+------------+
            |
            v
+------------------------+
| Compare with the       |
| hidden expected answer |
+-----------+------------+
            |
       PASS or FAIL
```

The expected answers are stored in the fixture but are removed before the
requests are sent to Hermes.

## What is evaluated

The fixture contains:

```text
11 current skills x 1 representative request
                         +
               1 unrelated request
                         =
                    12 cases
```

The unrelated request should produce `none`. This catches the simplest failure
where the model tries to use a repo skill for every possible question.

All cases are sent in one model call:

```text
Current skill catalog + 12 requests
                  |
                  v
          One Hermes call
                  |
                  v
   12 selected skill names or none
                  |
                  v
 Exact-match accuracy + batch wall time
```

## Repository files

- `evals/skill-routing.json` — requests and hidden expected answers
- `scripts/eval-skill-routing.py` — catalog discovery, Hermes invocation, scoring
- `tests/test_eval_skill_routing.py` — unit tests for the evaluator itself
- `private_dot_agents/private_skills/*/SKILL.md` — live skill catalog being tested

## Running it

First validate the catalog and fixture without making a model call:

```bash
python3 scripts/eval-skill-routing.py --dry-run
```

Then run the live routing eval with the current Hermes configuration:

```bash
python3 scripts/eval-skill-routing.py
```

To compare a configured model/provider explicitly:

```bash
python3 scripts/eval-skill-routing.py \
  --provider openai-codex \
  --model gpt-5.6-sol
```

The output reports one PASS/FAIL line per case, exact-match accuracy, prompt
bytes, and wall-clock time for the entire batch. One run is a point estimate,
not a stable latency distribution.

## What a passing result means

A pass provides evidence that the model can choose the intended skill from the
current names and descriptions:

```text
request -> correct skill selected
```

It does **not** prove the next stage:

```text
request -> select skill -> follow every instruction -> correct final result
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                  not covered by this eval
```

Full skill-body compliance would require separate, safe end-to-end cases.

## Extending the baseline

Keep the harness small. Improve the fixture first:

1. Add ambiguous contrast cases for skills that are easy to confuse.
2. Add more `none` cases to test false-positive routing.
3. Run repeated trials only when model variance matters.
4. Add end-to-end compliance tests only for deterministic, non-destructive tasks.

When a new repo-managed skill is added, add one representative positive case.
The dry run intentionally fails if the skill inventory and fixture drift apart.

## Keep these artifacts repo-only

`.chezmoiignore` must continue to exclude:

```text
docs/skill-routing-eval.md
evals/
tests/
scripts/eval-skill-routing.py
```

Do not move this guide into a managed `dot_` or `private_` target. After changing
ignore rules, verify that `chezmoi status` does not list this guide, the fixture,
the harness, or its tests as destination changes.
