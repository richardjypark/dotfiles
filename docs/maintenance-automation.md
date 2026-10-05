# Dependency maintenance

GitHub prepares repository tool updates. Each machine installs merged source
through chezmoi. Native package updates remain a separate host operation.

## Current delivery

The workflow `safe-daily-updates` has a manual pilot. Its default dispatch
reports updates. The optional `publish=true` dispatch creates or refreshes one
pull request. It does not apply home files. The daily schedule is not enabled.
Automatic merge remains off unless its repository variable is explicitly set.

The first group contains patch updates for Neovim, jj, uv, Starship, Bun and
chezmoi. Each release must be stable and at least seven full days old. All four
Linux/macOS artifact hashes must match the exact release. New minor and major
releases are reported for review. Pi and fzf remain manual: Pi needs verified
lock integrity repair; fzf needs an immutable source or verified artifact contract.

Dependabot separately proposes weekly GitHub Actions and OpenRouter npm
updates with a seven-day routine cooldown. All GitHub Actions updates share one
proposal. In the OpenRouter agent, the `@openrouter/*` packages share one group
because the agent and SDK versions must move together. All other minor and
patch updates share a second group. Each other major update remains a separate
proposal for review. Dependabot ignores `@openrouter/sdk` majors: every
`@openrouter/agent` release up to 0.11.0 requires SDK `^0.13.7`, and an SDK
major alone installs a second SDK copy that fails the type check. Remove that
rule when an agent release accepts the new SDK major. Dependabot also ignores
`@types/node` majors; change that major only with the Node runtime major.

The two Pi package directories get no version proposals; their limit is zero,
so Pi direct versions stay with the coordinated updater. Dependabot still
reports Pi alerts and tries security proposals. A proposal fails with
`security_update_not_possible` when the vulnerable package is inside the
published Pi shrinkwrap. Then repair both Pi lockfiles by hand: set the
version, resolved archive and integrity of the nested entry to the fixed
release. `npm-lock-install.py` installs that exact archive over the shrinkwrap
version, and the Linux managed npm suites check the installed versions.
Dependabot alerts and security update proposals must also be enabled in GitHub
repository settings.

When a Dependabot pull request is behind the base branch, comment
`@dependabot rebase`. Do not use the update-branch button. After another
account pushes to the branch, Dependabot stops its automatic rebases.

## Source checks and credentials

Preparation uses read permissions. The existing updater performs its atomic
transaction and rollback checks. A second checker permits only the six tools'
version and platform hash fields and their matching legacy version entries.
Comments, other settings and all other source paths must stay unchanged.

The candidate passes between jobs as base64 JSON, capped at 64 KiB. It contains
the exact base, repository/run identity, file hashes and contents, release dates,
and artifact hashes. The publisher checks this data again from the same trusted
base. It stops if the remote base moves, the PR head changes, an unexpected
branch exists, or more than one routine PR is open.

The publication job installs verified tools and completes fresh release checks
before it mints the App token. It runs trusted publication code, uses explicit
changed paths and a no-reply App identity, and pushes through `dotfiles-push`.
It does not execute candidate scripts or npm packages with that token. If a
branch push succeeds but PR creation fails, a retry can recover the same run's
branch only after it verifies the App identity, parent and exact source bytes.

The `maintenance-policy` workflow uses `pull_request_target` to load trusted
base code. It reads the candidate as Git objects and runs no candidate code.
Its token has content reads and commit-status writes. It records the required
`dependency-policy` result on the candidate head, because a target workflow's
normal check run refers to the base commit. See GitHub's
[event reference](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request_target)
and [commit status API](https://docs.github.com/en/rest/commits/statuses).
The ordinary PR test matrix keeps
read permissions and receives no App key or publication token.

For App PRs and reserved maintenance branches, the policy checks patch scope,
release age and upstream artifact hashes. Other PRs retain tool integrity and
version consistency checks without the routine age or patch restriction.

## Configure the publication pilot

1. Merge the implementation through the normal protected PR path.
2. Create and install a GitHub App on this repository only. Grant contents and
   pull-request reads/writes. Leave workflow writes, administration and ruleset
   bypass ungranted. Record an owner and key replacement procedure.
3. Create the `dotfiles-maintenance` environment. Restrict deployment to the
   repository default branch. Store `DOTFILES_MAINTENANCE_APP_PRIVATE_KEY` there
   as a secret through the normal GitHub secret process. Keep the key out of
   source files and logs.
4. Set repository variables `DOTFILES_MAINTENANCE_APP_CLIENT_ID` and
   `DOTFILES_MAINTENANCE_APP_SLUG`. The slug excludes the `[bot]` suffix.
   Leave `DOTFILES_MAINTENANCE_PUBLISH` and `DOTFILES_MAINTENANCE_AUTOMERGE`
   unset during the manual pilot.
5. Enable Dependabot alerts and security update proposals. Verify that the old
   `pi-maintenance-agent.timer` and `.service` are inactive on each Linux host.
6. Run a report on the default branch. When an eligible patch exists, dispatch
   the same workflow with `publish=true`. No eligible change produces no PR.
7. Confirm that the real App PR starts ordinary checks without a workflow
   approval, gets a successful `dependency-policy` status on its current head,
   and passes Linux, macOS and gitleaks. Review and merge the pilot manually.

Use GitHub Actions, or run from an authenticated CLI:

```sh
gh workflow run safe-daily-updates.yml
gh workflow run safe-daily-updates.yml -f publish=true
```

App installation tokens are restricted to this repository and expire after one
hour. The token action revokes them at job completion. The private key remains
long-lived and needs periodic replacement.

## Activate routine updates after the pilot

Require these exact successful contexts from GitHub Actions in the default
branch ruleset: `gitleaks`, `validation (ubuntu-24.04)`,
`validation (macos-26)` and `dependency-policy`. Keep base freshness and PR
requirements active. The publisher checks those effective rules before it
requests automatic merge. macOS currently runs the core suites; the full
managed npm suites are required on Linux.

Add this trigger under `on` in `safe-daily-updates.yml` only after the pilot and
Linux writer checks pass:

```yaml
schedule:
  - cron: '23 8 * * *'
```

Then set `DOTFILES_MAINTENANCE_PUBLISH=true`. Set
`DOTFILES_MAINTENANCE_AUTOMERGE=true` only after the four required checks are
active. The writer uses one concurrency group and at most one open routine PR.
Its merge request includes the expected head commit and uses the normal rules.

Review failed runs and the last successful check time. GitHub schedules can be
delayed or disabled after inactivity. A schedule does not provide a fixed update
deadline. Security proposals have a separate review path; keep mandatory tests
and integrity checks for urgent fixes.

## Local use and recovery

After deployment of the managed command, use:

```sh
TRUST_ON_FIRST_USE_INSTALLERS=1 czu --reviewed
```

`--reviewed` accepts no additional apply arguments. It requires a clean current
change, syncs the selected source, rejects conflicts and unmerged source changes,
then runs an incremental apply and the health check. It saves a private success
receipt at `${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-maintenance/last-reviewed-update.json`
only after both succeed. Failure preserves the previous receipt. Plain `czu`
keeps its existing development behavior.

Installer trust remains explicit for each run. Several native installations use
pins as minimum versions; Homebrew and Arch can install newer versions. The
seven-day rule applies to routine source proposals, not every native package.
`czm` and `czl` keep their current behavior until approved macOS and Arch pilots
verify the later command transition. Measure unchanged-tool installs and apply
time before adding a background download timer.

On a failed proposal, keep the PR and its checks for diagnosis. On a publisher
failure, leave report mode available and stop routine publication. On a bad
merged update, use a reviewed forward fix or revert PR. Source rollback does
not undo native package upgrades or restore every host file. Preserve config
backups and prior verified binaries where the installer supports them.

## Verification limits

Offline regression tests cover source scope, artifact identity, stale data,
branch races, App commit identity, guarded push, PR failure/recovery and local
apply gates. They include real Git/jj transactions with simulated GitHub
responses. The GitHub pilot verifies actual App permissions, event behavior and
required status attachment. Approved host pilots verify real installation and
package-manager convergence. Passing offline tests does not replace those pilots.
