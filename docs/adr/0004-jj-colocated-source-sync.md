# The chezmoi source is a colocated jj workspace

The dotfiles source is a jj repository colocated with Git. Tools that read Git state must allow for jj:

- Git `HEAD` is the parent of the jj working-copy commit, and it is detached. Compare remote state with `HEAD`, not with the empty working commit, or every check reports an update (`dotfiles-update-check`). Show the nearest jj bookmark or change ID instead of a branch name (statusline).
- Snapshot first. `jj status` or `jj util snapshot` records local edits before a tool reads Git refs (`dotfiles-push`) or fetches with `--ignore-working-copy` (`jj-sync-trunk`). `dotfiles-update` snapshots the current change and never renames existing user work.
- A rewritten remote trunk shares only `root()` with `@`, and the fetch moves `@` onto `root()`. Rebase with `--ignore-working-copy` first, then run `workspace update-stale`. A rebase that updates files itself first checks out the empty root tree: that deletes every tracked file, `.gitignore` too, and the next snapshot adds every ignored file to `@`. `tests/test-chezmoi-update-helpers.sh` covers this with real jj.
- `jj-sync-trunk` asks the remote for its default branch (`ls-remote --symref`) and falls back to cached refs only when offline, because the local `origin/HEAD` can be stale.
- The installed update checker runs the release-eligibility helper from `trunk()`, not from the working copy, so a timer never executes unreviewed local edits.
