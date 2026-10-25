---
name: ssh-lockdown-model-check
description: "Model-check the SSH lockdown rollback in scripts/server-lockdown-tailscale.sh with TLA+ (TLC): every order of the lockdown run, the five-minute rollback timer, and --confirm runs. Use before and after any change to that script, its rollback.sh heredoc, or its confirm or rollback steps, and when you investigate a VPS that lost SSH access or kept a half-restored SSH or UFW config."
---

# SSH Lockdown Model Check

`scripts/server-lockdown-tailscale.sh` changes SSH and UFW on a remote server. Its safety net is a five-minute systemd timer that runs `rollback.sh` unless a new SSH session runs `--confirm`. Tests cannot run the real sshd, UFW, and timer, and they cannot reach the orders of events that matter. This skill checks a TLA+ model of the script in every order of steps.

## Rules

Each rule is checked in each scenario. "Settled" means no command runs and no timer is armed.

| Rule | Plain sentence | Harm if broken |
| --- | --- | --- |
| `ConfirmedMeansLocked` | When `--confirm` says "Lockdown confirmed", the server runs the lockdown policy, on disk and live. | The user trusts a hardening that is not there. |
| `SettledConsistent` | When everything settles, the server has the whole prior SSH and firewall config or the whole lockdown config, not a mix. | Behavior changes silently at the next sshd restart or reboot. |
| `NoLockout` | When everything settles, a new SSH session over Tailscale can connect now and after the next sshd restart or reboot. | The user loses remote access. |
| `UnconfirmedRestores` | If no `--confirm` run succeeds, the prior config comes back and stays. | An untested lockdown stays in place. |

## Run

```bash
CHECK=~/.agents/skills/ssh-lockdown-model-check/scripts/check-ssh-lockdown
"$CHECK" --source ~/.local/share/chezmoi run       # all scenarios, compares with spec/expected.json
"$CHECK" mutants                                   # proves that each rule and each guard can fail
"$CHECK" trace Interrupted NoLockout               # full TLC output for one result
```

- If you changed this skill and did not apply yet, run the source copy: `python3 ~/.local/share/chezmoi/private_dot_agents/private_skills/ssh-lockdown-model-check/scripts/executable_check-ssh-lockdown`.
- Needs Java 11 or later. The helper downloads `tla2tools.jar` v1.7.4 from the tlaplus GitHub release once, checks its SHA-256 (`936a2620…0e88`, recorded on first use 2026-10-25; upstream publishes no digest for v1.7.4), and caches it in `~/.cache/ssh-lockdown-model-check/` (or `$TMPDIR` when that is not writable). `--jar PATH` uses a local copy with the same digest.
- TLC binds a local RMI port for every run. In the Claude Code sandbox that fails with `Listen failed on port: 0`, and the download fails without github.com. Run the helper with the sandbox disabled, or set `sandbox.network.allowLocalBinding: true`.
- A full `run` makes 12 TLC runs and takes about 10 seconds. Logs stay in `$TMPDIR/ssh-lockdown-model-check/results/<time>/`.
- Exit code `0` means every result equals `spec/expected.json` and the covered script equals the sync record. `CHANGED` on a line means that result moved; exit code `1` lists how many. Exit code `3` means the results match, but the script changed since the sync commit, so the pass can describe old code. Follow "When a change touches covered code".

## Scenarios

The constants are in `spec/<Scenario>.cfg`. In every scenario, `systemctl stop` on the timer can fail, because a fired transient timer can already be gone.

| Scenario | Setup | Expected now |
| --- | --- | --- |
| `Baseline` | Server locked down before on port 2200, now locked down on port 22. UFW active. No interrupt. | All rules pass. |
| `FirstLockdown` | New VPS: no drop-in, UFW inactive, port 22 before and after. | All rules pass. |
| `Interrupted` | Baseline, but the lockdown run can stop between any two commands (Ctrl-C, or the first SSH session drops). | All rules pass. |

## Fixed findings

Two findings from the first model are fixed. A mutant guards each fix, so a regression shows as a killed-mutant failure.

**F1: `--confirm` raced the rollback it cancels.** The timer could fire while `--confirm` ran its checks. `--confirm` then removed the state directory while `rollback.sh` ran. The user saw "Lockdown confirmed", but the drop-in could be deleted, the old drop-in could be on disk with lockdown UFW rules (lockout at the next sshd restart), or UFW could be disabled. Fix: `rollback.sh` and `--confirm` hold one `flock` on `/run/dotfiles-ssh-lockdown.lock` (L124-L125, L189-L190). `rollback.sh` exits when the state directory is gone (L126) and reads the UFW status before it changes anything (L127). `--confirm` ignores a failed `systemctl stop`, because a fired rollback then waits for the lock and finds no state directory (L203-L206). Mutants: `confirm-without-lock`, `rollback-without-lock`.

**F2: an interrupt inside `rollback_now` removed the safety net.** `rollback_now` stopped the timer before it restored, so an interrupt between the two left the lockdown files with no rollback. Fix: `rollback_now` runs `rollback.sh` first and stops the timer only after the restore ends (L150-L157). Mutant: `rollback-now-stops-timer-first`.

`tests/test_access_guards.py` (`LockdownRollbackTest`) replays both fixes against the real `rollback.sh` text. One test uses the real util-linux `flock` and skips when it is not installed (macOS).

## Coverage

- Sync commit: `covered.sync_commit` in `spec/expected.json`. That file also records the SHA-256 of `scripts/server-lockdown-tailscale.sh` at that commit, and `run` exits `3` when the file differs.
- Covered: `prepare_rollback` (L99-L148), the `rollback.sh` heredoc (L118-L141), `rollback_now` (L150-L157), `apply_lockdown` (L159-L183), `confirm_lockdown` (L185-L209), `main` (L211-L233). Each model action names its lines.
- Abstracted: `assert_sshd_policy`, `assert_listener`, and `assert_ufw_policy` become checks on the model state (drop-in on disk, running sshd port, live UFW). The files in `/run/dotfiles-ssh-lockdown` are one unit. UFW has four states: prior, partial (L175-L180 done), lock, off.
- Not covered: `scripts/setup-personal-cloud-tailscale.sh` (it has the same lock, state check, status reads, and `rollback_now` order, but only regression tests cover it), `validate_session`, `scripts/lib/tailnet-access.sh`, `bootstrap-vps.sh`, sshd key and auth behavior, IPv6 rules, and the exact parsing in `public_ssh_rule_present`.

Assumptions:

- One lockdown run at a time (the L100 check and L104 `install -d` are not atomic).
- `apply_lockdown` and `rollback_now` finish within five minutes, so the timer fires only after the run ends.
- No reboot while a lockdown is pending (the usage text forbids it; `/run` and the transient timer do not survive it).
- Restore commands in `rollback.sh` succeed when their files exist.
- The prior firewall lets the prior SSH port in over Tailscale.
- A process that waits in `flock` gets the lock when it is free again (strong fairness for `rollback.sh`). Linux wakes the waiter at once, while a new `--confirm` takes a person seconds to type. With weak fairness, endless `--confirm` retries could starve the rollback.

## When a change touches covered code

1. Run `"$CHECK" --source <checkout> run` before you change anything, and keep the result.
2. Read the diff of the covered functions. For each changed command, find the model action with that line comment in `spec/SshLockdown.tla`.
3. Change the model from the code first: one command is one action, and a new branch or a new failure is a new disjunct. Update the line comments. Do not shape the model by what makes the check pass.
4. Run `run`, then `mutants`. A mutant marked `STALE` points at model text that you changed: update its `old` and `new` so it still mirrors the same break.
5. A result marked `CHANGED`:
   - A pass that became a violation is a bug candidate. Read the trace (`trace SCENARIO RULE`), tell it as steps in the script's words, and replay the bash part against the real script text with stubs before you call it a bug. If the replay disagrees, the model is wrong: fix the model, not the rule.
   - A violation that became a pass, after a change meant to fix it, is a fix. Update that scenario in `spec/expected.json`.
6. Change a rule only when the script's promise changed on purpose, and cite the evidence (usage text, commit message, docs).
7. After the model again describes the code, update `covered.sync_commit` and the SHA-256 in `spec/expected.json`, and this file's line references.

When the pstack plugin is installed, read each TLC result with its `statechart` skill (`/pstack:statechart` in Claude Code). It tells each violation as a short path in plain words, and charts the passing state space. Start it from a copy of `spec/SshLockdown.tla`, outside the repo.

## Files

- `spec/SshLockdown.tla`: the model and the four rules.
- `spec/*.cfg`: scenario constants. The helper adds `SPECIFICATION`, `TypeOK`, and one rule per TLC run.
- `spec/expected.json`: coverage record, expected result for each scenario and rule, and mutants.
- `scripts/check-ssh-lockdown`: the helper (Python 3, standard library only).
