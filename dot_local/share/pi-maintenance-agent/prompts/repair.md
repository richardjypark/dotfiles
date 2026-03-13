You are operating in a jj-backed chezmoi source repository with a conflicted or ambiguous working copy.

Goal:
- summarize the issue
- attempt one automated repair
- stop after that repair attempt

Constraints:
- do not ask follow-up questions
- make at most one repair attempt
- do not push
- do not create new files unless a tool requires a temporary file internally
- if the repair does not fully resolve the issue, stop and explain what remains

Required workflow:
1. Inspect the repo state and summarize the conflict or ambiguity.
2. Attempt one repair.
3. Re-check repo state.
4. Print a short result summary and stop.
