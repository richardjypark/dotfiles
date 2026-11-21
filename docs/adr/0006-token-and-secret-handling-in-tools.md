# Tokens never reach argv, logs, redirects, or unscanned files

- `chezmoi-bump` uses the `gh` login only when `GITHUB_TOKEN` is unset (`CHEZMOI_BUMP_GH_AUTH=0` disables it), does not export the token, and gives it only to `_curl_gh` and the release-eligibility helper. curl reads the `Authorization` header from a stdin config (`-K -`), so the token is not in `ps` output.
- `stable-release-eligibility.py` sets the header with `add_unredirected_header`, so urllib does not send it to a redirect target.
- `r2-alert-agent` logs only the error class and status of a failed Telegram send, because the URL holds the bot token.
- `publish-maintenance-candidate.py` uses `gh auth git-credential` as the credential helper; the helper holds no token, and gh reads the short-lived token from its environment.
- `npm.sh` reads publication times from `registry.npmjs.org` directly, so a scoped registry in `.npmrc` cannot supply them for automatic proposals.
- `dotfiles-secret-scan` checks Git's index too, so a forced `git add` cannot bypass the private-file rules, and it runs the policy script from the checkout rather than an older installed copy. gitleaks directory scans include ignored files, so for a repository root it scans a snapshot of tracked and non-ignored untracked files: machine-local credentials stay private, and accidental unignored files are still scanned.
- The OpenRouter agent strips a leading byte-order mark before `parseEnv`, which would otherwise keep it in the first key name.
