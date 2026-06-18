---
name: secret-leak-audit
description: Use when auditing this dotfiles repo or another Git repository for leaked secrets, personal access tokens, private keys, sensitive filenames, or PII exposure; also use before commits that touch credentials, env examples, CI, bootstrap, or secret-handling docs.
license: MIT
---

# Secret Leak Audit

Audit for leaked secrets without exposing them in chat, logs, reports, or commits.

## When to use this skill

Use this skill when:

- the user asks whether a project or commit history leaked secrets, PATs, tokens, private keys, credentials, or personal sensitive information
- changes touch `.env` examples, CI, bootstrap scripts, SSH/Tailscale/GitHub/auth flows, or secret-handling docs
- preparing a commit where a secret scanner should run first
- triaging GitHub secret-scanning, gitleaks, trufflehog, or similar findings

## Safety rules

- Never print raw secret values. Redact scanner output and summarize by rule, path, line, and commit only.
- Do not paste matching source lines unless you have verified they contain only placeholders or public examples.
- Treat unknown high-entropy values as sensitive until proven otherwise.
- If a real secret is found, recommend rotation/revocation first; history cleanup does not make an exposed token safe.
- Do not rewrite shared Git/JJ history without explicit user approval.

## Dotfiles repo quick path

From `~/.local/share/chezmoi`, prefer the managed helper:

```bash
# Full local audit: full Git history plus current checked-out files
dotfiles-secret-scan --all

# Source-tree fallback before chezmoi apply has rendered ~/.local/bin
dot_local/bin/executable_dotfiles-secret-scan --all

# Git pre-commit hook mode; note that JJ commits do not run Git hooks
dotfiles-secret-scan --staged
```

The helper runs gitleaks with `--redact=100`. If `gitleaks` is missing but Go is available, it installs the pinned gitleaks version into the user cache.

A repo-local Git hook is available at `.githooks/pre-commit`. Enable it per clone with:

```bash
git config core.hooksPath .githooks
```

Keep the GitHub Actions workflow `.github/workflows/secret-scan.yml` enabled; it scans full history and the checked-out worktree on PRs, pushes to `master`/`main`, weekly schedule, and manual dispatch.

## Audit workflow

1. Check repo state:
   ```bash
   git status --short
   git rev-list --count --all
   ```
2. Run gitleaks with full redaction:
   ```bash
   gitleaks git --log-opts="--all" . --redact=100 --no-banner --log-level warn
   gitleaks dir . --redact=100 --no-banner --log-level warn
   ```
   Use `dotfiles-secret-scan --all` in this repo.
3. Run a targeted supplemental scan when the user asked about PII or sensitive filenames:
   - private key headers
   - GitHub PAT prefixes (`ghp_`, `github_pat_`, `gho_`, `ghu_`, `ghs_`, `ghr_`)
   - OpenAI/Anthropic/AWS/Slack/Stripe/Google/Tailscale token shapes
   - generic `token`, `secret`, `password`, `credential`, or `api_key` assignments with long values
   - sensitive filenames such as `.env`, `.env.*`, `*.pem`, `*.p12`, `*.pfx`, `*.key`, `*credentials*.json`, `*secrets*.json`
4. If GitHub is authenticated and the repo is on GitHub, query secret-scanning alerts without printing `secret` fields:
   ```bash
   repo=$(git remote get-url origin | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')
   gh api -H 'Accept: application/vnd.github+json' "/repos/${repo}/secret-scanning/alerts?per_page=100" \
     --jq 'map({number,state,secret_type,created_at,resolved_at,html_url}) | {count:length, alerts:.}'
   ```
5. Review findings manually using redacted context. Classify as:
   - real exposed secret
   - placeholder/example
   - public non-secret identifier
   - scanner false positive

## Response template

Report:

- scanners and scope used, including commit count for history scans
- whether any verified/likely leaked secrets were found
- redacted finding summary by rule/path/commit, if any
- intentional personal data that remains tracked, if relevant (for example Git author identity data)
- action plan: rotate/revoke, remove from tip, rewrite history only with explicit approval, add/adjust scanner rules, and verify CI

## If a real leak is found

1. Revoke or rotate the token/key immediately in the provider console.
2. Identify blast radius: provider, scopes, creation time, logs, and any automation using it.
3. Remove the secret from the current tree and replace with an env var, untracked local file, or encrypted chezmoi secret.
4. Add a regression guard: gitleaks rule, CI workflow, hook, or `.gitignore`/`.chezmoiignore` entry.
5. Only after rotation, discuss history rewrite options (`git filter-repo`, BFG, or equivalent JJ/Git workflow). Require explicit user approval before rewriting or force-pushing.
6. Re-run full history and worktree scans, then verify GitHub secret-scanning alerts are closed or documented.

## Validation checklist

- [ ] `dotfiles-secret-scan --all` or equivalent gitleaks history + worktree scans pass with redaction enabled
- [ ] supplemental sensitive filename/token-shape scan has no unexplained hits
- [ ] GitHub secret-scanning alerts checked when available
- [ ] `.github/workflows/secret-scan.yml` remains present and scoped to read-only contents
- [ ] no raw secrets appear in final notes, reports, commits, or chat
