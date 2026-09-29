# Secrets Management

This guide covers how to manage secrets in the chezmoi dotfiles repository.

## Current Approach: Untracked Environment Files

The repository uses untracked local files for sensitive values. This avoids committing secrets to git while keeping configuration flexible.

**Bootstrap private config:**
```
~/.config/dotfiles/bootstrap-private.env
```

**Pi maintenance runtime config:**
```
~/.config/dotfiles/pi-maintenance-agent.env
```

**Optional OpenRouter reserve agent:**
```
~/.hermes/.env
```

These files are machine-local and never committed. Example bootstrap contents:

```bash
TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
GITHUB_TOKEN=ghp_xxxxx
```

For the optional `openrouter-agent`, `~/.hermes/` must be a current-user-owned directory that is not
a symlink or writable by group/others, and `~/.hermes/.env` must be a current-user-owned regular
file with mode `0600`; symlinks and looser permissions are rejected. The loader reads only
`OPENROUTER_API_KEY` and does not import unrelated variables into the process environment. An
already-exported `OPENROUTER_API_KEY` takes precedence. Create or edit the file locally rather than
passing the key on a command line, where shell history or process listings could capture it. The
repo contains only the variable name and setup instructions, never a value. Selecting the optional
Kimi profile changes only the non-secret `OPENROUTER_AGENT_MODEL` process variable; it uses the same
private key-loading path and does not require a second credential file.

## Automated Secret Scanning

This repo checks both file names and secret values:

1. **CI trigger:** `.github/workflows/secret-scan.yml` scans the full Git
   history and checked-out worktree on pull requests, pushes to every branch,
   a weekly schedule, and manual dispatch. It also rejects tracked ignored
   files and personal email addresses in new commits. Scanner output is fully
   redacted. The default branch requires the `gitleaks` check; see
   [Publishing to master](#publishing-to-master).
2. **Local helper:** `dotfiles-secret-scan` runs the same redacted checks from a
   clone. Before `chezmoi apply` has rendered the helper, run the source script
   directly:

   ```bash
   # Full history + current worktree
   dot_local/bin/executable_dotfiles-secret-scan --all

   # Staged-only mode for a Git pre-commit hook
   dot_local/bin/executable_dotfiles-secret-scan --staged
   ```

Enable the Git hooks and the guarded JJ push alias in each clone:

```bash
git config core.hooksPath .githooks
jj config set --repo aliases.push \
  '["util", "exec", "--", "dotfiles-push"]'
```

Run `chezmoi apply` to install `dotfiles-push`, or use the source command before
the first apply:

```bash
dot_local/bin/executable_dotfiles-push --bookmark my-change --remote origin
# After installation and local alias setup:
jj push --bookmark my-change --remote origin
```

The publisher accepts one exact bookmark and a configured remote. It checks
every outgoing commit's tree and author/committer email, then scans all local
Git history and the worktree. An error stops the push. Fetch the remote before
publication so the outgoing-commit check uses current remote references.
`--dry-run` runs the checks and then previews the push.

Git's pre-commit hook checks staged changes. Its pre-push hook checks outgoing
commit metadata and scans history. Hooks prefer the current source scanner.
JJ does not run Git hooks: raw `jj git push` bypasses these local checks.
Use `dotfiles-push` or the repository's `jj push` alias. The `jp` and `jj-fzf`
shortcuts use that alias. CI runs after data has reached GitHub; it cannot
prevent the first publication of a secret. Push protection adds an independent
check for supported secret types.

## Publishing to master

Every change reaches `master` through a pull request. No actor can bypass the
rules, including the repository admin:

```bash
dotfiles-push --bookmark my-change --remote origin
gh pr create --base master --head my-change --fill
gh pr merge my-change --auto --merge --delete-branch
```

GitHub merges the pull request after the required checks pass. The pull
request, its check runs, and the ruleset log are the audit record, and a
`bypass` result in that log is always unexpected.

Expected GitHub settings:

- Ruleset "Protect master" (default branch): block deletion and force pushes;
  require a pull request with 0 approvals and merge commits only; no bypass
  actors. Merge commits keep the branch commit IDs, so local JJ history stays
  valid after the merge.
- Ruleset "Required checks" (default branch): require `gitleaks` and
  `validation (ubuntu-24.04)` from GitHub Actions, with the branch up to
  date; no bypass actors.
- Repository: merge commits only, auto-merge on, delete branch on merge on.
- Secret scanning and push protection on. GitHub does not turn on
  non-provider patterns or validity checks for this repository; the local
  and CI gitleaks scans cover generic secrets.

If `master` moves before the merge, rebase the change with `jj rebase` and run
`dotfiles-push` again. If GitHub Actions is down, disable only the "Required
checks" ruleset, merge, and enable it again; GitHub records the change. Keep
"Protect master" active at all times.

Check the live rules and recent rule results:

```bash
gh api 'repos/{owner}/{repo}/rules/branches/master'
gh api 'repos/{owner}/{repo}/rulesets/rule-suites?ref=refs/heads/master'
```

## Public identity and private source files

The managed Git and JJ defaults use a GitHub no-reply email address. On a
machine with a repository-local identity override, set the local Git/JJ email
to the no-reply address from GitHub Settings > Emails as well. New outgoing
commits must use a GitHub no-reply address for both author and committer.
Old commit names, emails, timestamps, file contents, and public log copies
remain public. Changing the current configuration does not remove history.

`.gitignore` covers both raw private files and common chezmoi source names,
including SSH/cloud credentials, authentication state, and shell history.
`scripts/check-public-files.py` rejects tracked files that match the ignore
rules, including files added with `git add -f`. It also checks intermediate
outgoing commits, so adding a private file and deleting it before pushing
does not pass the check. Keep intentional public exceptions explicit and narrow.

The `private_` prefix sets owner-only target permissions; it provides no
encryption or GitHub access control. `.chezmoiignore` controls which target
files chezmoi manages. Git publication is controlled by Git's index and
`.gitignore`, with the publication checks above as additional protection.

## Optional: GPG Encryption with Chezmoi

For secrets that need to travel with the repo (API keys referenced in templates, etc.), chezmoi supports GPG-encrypted files.

### Setup

1. **Create or import a GPG key:**
   ```bash
   gpg --full-generate-key  # Create new key
   gpg --list-keys           # Find your key ID
   ```

2. **Configure chezmoi to use your key:**
   Add to `~/.config/chezmoi/chezmoi.toml`:
   ```toml
   encryption = "gpg"
   [gpg]
       recipient = "your-email@example.com"
   ```

3. **Add encrypted template data:**
   ```bash
   chezmoi add --encrypt ~/.config/dotfiles/secrets.toml
   ```
   This creates an encrypted file in the source directory that chezmoi decrypts on `apply`.

### Using Encrypted Data in Templates

Create an encrypted data file (e.g., `.chezmoidata/secrets.toml.age` or `.chezmoidata/secrets.toml.asc`):

```toml
[secrets]
api_key = "sk-xxxxx"
```

Reference in templates:
```
{{ .secrets.api_key }}
```

### Workflow

```bash
# Encrypt a file
chezmoi add --encrypt ~/path/to/secret-file

# Edit an encrypted file
chezmoi edit --encrypt ~/path/to/secret-file

# Re-encrypt after GPG key change
chezmoi re-add
```

## Best Practices

1. **Never commit plaintext secrets** to the repository
2. **Use untracked env files** (`bootstrap-private.env`) for deployment-specific secrets
3. **Keep machine-local runtime configs untracked** (for example `pi-maintenance-agent.env`)
4. **Use GPG encryption** only when secrets must travel with the repo
5. **Prefer environment variables** over files for runtime secrets
6. **Rotate secrets** if you suspect the GPG key or env file was compromised
7. **Keep plaintext secrets out of Git's index.** Add raw and chezmoi source
   names to `.gitignore`. Use `.chezmoiignore` separately for target exclusions.
   A matching ignore rule does not untrack an existing file. Encrypted source
   files also need reviewed names; do not force-add an ignored private path.

## Reference

- [Chezmoi encryption docs](https://www.chezmoi.io/user-guide/encryption/)
- [GPG quick start](https://www.chezmoi.io/user-guide/encryption/gpg/)
- [age encryption alternative](https://www.chezmoi.io/user-guide/encryption/age/)
