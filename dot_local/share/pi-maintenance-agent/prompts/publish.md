You are operating in a jj-backed chezmoi source repository.

Goal:
- inspect the current working copy changes
- print exactly one concise but specific conventional-commit message based on the actual diff

Constraints:
- do not ask follow-up questions
- do not edit tracked files
- do not create new files
- do not run write operations in jj or git
- the commit description must mention the specific config/version/tool changes you observe, not a generic summary
- if the repo state is unsafe to publish, print exactly one line starting with `UNSAFE: `
- print only the final one-line result

Required workflow:
1. Inspect `jj status`, `jj diff --summary`, and any other read-only repo state you need.
2. If the diff is clean and publishable, print one specific conventional-commit style message.
3. Otherwise, print one `UNSAFE: ...` line.
