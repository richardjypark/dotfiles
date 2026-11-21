---
name: delete-comment
description: "Audit and delete code comments in this repo under the comment ratchet: sort each comment as tautology, stale, excuse, or decision record, delete the first three, draft an issue for each excuse, move decision records into docs/adr/, and lower tests/comment-baseline.tsv. Use for /delete-comment, a comment clean-up pass, or when the comment-ratchet suite fails."
---

# Delete Comment

The repo bans new code comments (`docs/adr/0001-no-code-comments.md`). `scripts/comment-ratchet.py` counts comment lines per file, and `tests/comment-baseline.tsv` holds the allowed count, which only goes down. Use this skill to take the next bite out of the baseline.

## 1. Pick the scope

Ask for a path if the request names none. Default to the files with the highest baseline:

```sh
sort -rn tests/comment-baseline.tsv | head -15
python3 scripts/comment-ratchet.py --list PATH...
```

`--list` prints only counted comments. Shebangs, tool pragmas, `{{ }}` hash triggers in chezmoi templates, and heredoc bodies are exempt: never delete them. A hash trigger makes a `run_onchange_` script rerun; a heredoc line is content that the script writes.

## 2. Sort each comment

Read the comment with the code around it, then choose one category:

| Category | Test | Action |
|---|---|---|
| Tautology | The code beside it already says it: section banners, "Install X" above `install_x`, "Verify installation". | Delete. |
| Stale | It names a file, count, function, or behavior that is no longer true. Check with grep before you decide. | Delete. |
| Excuse | It explains why a workaround, shim, global, duplicate constant, or skipped dependency is acceptable for now ("older setup", "be safe", "CI installs X", "sets global arrays"). | Delete, and draft an issue that names the fix and an acceptance check. |
| Decision record | It records a non-obvious reason that a future reader would otherwise "fix": an OS or tool bug, a security property, an ordering or locking rule, a rejected alternative. | Move into an ADR, then delete. |

When unsure between tautology and decision record, ask: would a careful engineer reading only the code change it and break something? If yes, it is a decision record.

## 3. Move decision records

Put each decision record in the ADR whose theme fits (`ls docs/adr/`). Add a bullet that names the function or script, not a line number. Make a new ADR only for a new theme: use the next number and the format in the `domain-modeling` skill's `ADR-FORMAT.md`. A comment that only restates a test's assertion is a tautology, not a decision record.

## 4. Draft issues for excuses

Write each issue as a title with a conventional prefix, the file and function, why the workaround exists, and the fix with an acceptance check. Keep drafts in `plans/YYYY-MM-DD-comment-excuse-issues.md` (ignored by Git). File them with `gh issue create` only after the user approves.

## 5. Delete safely

- Delete the whole comment block. If it sat between two blank lines, also remove one blank line.
- For a trailing comment, keep the code and strip the comment and the spaces before it.
- Never leave an empty shell block (`then` directly followed by `fi`) or an empty Python body. Keep the comment for a later pass instead.
- Leave the SSH lockdown scripts to a pass that also runs the `ssh-lockdown-model-check` skill.
- Changing a `run_onchange_` script, or a helper whose hash it includes, makes chezmoi rerun it on the next apply. Say so in the change summary.

## 6. Lock in and verify

```sh
python3 scripts/comment-ratchet.py --update   # lowers the baseline; refuses an increase
python3 scripts/comment-ratchet.py --check
bash tests/syntax
python3 tests/test_comment_ratchet.py
```

Then follow the repo validation steps in `AGENTS.md` (`./tests/all`, `chezmoi diff`). Report the lines removed per category, the ADRs changed, the drafted issues, and the new baseline total.
