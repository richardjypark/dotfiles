You are operating in a jj-backed chezmoi source repository.

Goal:
- inspect the current working copy changes
- write a concise but specific commit description based on the actual diff
- move the `master` bookmark to `@`
- push `master`
- run `jj new`

Constraints:
- do not ask follow-up questions
- do not edit tracked files
- do not create new files
- do not push anything except the `master` bookmark
- the commit description must mention the specific config/version/tool changes you observe, not a generic summary
- if the repo state is unsafe to publish, stop and explain why in one short paragraph

Required workflow:
1. Inspect `jj status`, `jj diff --summary`, and any other read-only repo state you need.
2. If the diff is clean and publishable, set the working copy description to a specific conventional-commit style message.
3. Run `jj bookmark move master --to @`.
4. Run `jj git push -b master`.
5. Run `jj new`.
6. Print a short summary of what you published.
