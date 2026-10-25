---
name: ssh-lockdown-model-check
description: "Model-check the SSH lockdown rollback in scripts/server-lockdown-tailscale.sh with TLA+ (TLC): every order of the lockdown run, the five-minute rollback timer, and --confirm runs. Use before and after any change to that script, its rollback.sh heredoc, or its confirm or rollback steps, and when you investigate a VPS that lost SSH access or kept a half-restored SSH or UFW config."
---

# SSH Lockdown Model Check

`scripts/server-lockdown-tailscale.sh` changes SSH and UFW on a remote server. Its safety net is a five-minute systemd timer that runs `rollback.sh` unless a new SSH session runs `--confirm`. Tests cannot run the real sshd, UFW, and timer, and they cannot reach the orders of events that matter. This skill checks a TLA+ model of the script in every order of steps, and records two findings in the current code.

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
"$CHECK" mutants                                   # proves that each rule can fail
"$CHECK" trace Interrupted NoLockout               # full TLC output for one result
```

- If you changed this skill and did not apply yet, run the source copy: `python3 ~/.local/share/chezmoi/private_dot_agents/private_skills/ssh-lockdown-model-check/scripts/executable_check-ssh-lockdown`.
- Needs Java 11 or later. The helper downloads `tla2tools.jar` v1.7.4 from the tlaplus GitHub release once, checks its SHA-256 (`936a2620…0e88`, recorded on first use 2026-10-25; upstream publishes no digest for v1.7.4), and caches it in `~/.cache/ssh-lockdown-model-check/` (or `$TMPDIR` when that is not writable). `--jar PATH` uses a local copy with the same digest.
- TLC binds a local RMI port for every run. In the Claude Code sandbox that fails with `Listen failed on port: 0`, and the download fails without github.com. Run the helper with the sandbox disabled, or set `sandbox.network.allowLocalBinding: true`.
- A full `run` makes 16 TLC runs and takes about 10 seconds. Logs stay in `$TMPDIR/ssh-lockdown-model-check/results/<time>/`.
- Exit code `0` means every result equals `spec/expected.json` and the covered script equals the sync record. `CHANGED` on a line means that result moved; exit code `1` lists how many. Exit code `3` means the results match, but the script changed since the sync commit, so the pass can describe old code. Follow "When a change touches covered code".

## Scenarios

The constants are in `spec/<Scenario>.cfg`.

| Scenario | Setup | Expected now |
| --- | --- | --- |
| `Baseline` | Server locked down before on port 2200, now locked down on port 22. UFW active. `systemctl stop` fails on a timer that has fired. No interrupt. | All rules pass. |
| `FirstLockdown` | New VPS: no drop-in, UFW inactive, port 22 before and after. | All rules pass. |
| `TimerStillLoaded` | Baseline, but `systemctl stop` can succeed on a timer that has fired while its `rollback.sh` runs. | F1 breaks `ConfirmedMeansLocked`, `SettledConsistent`, `NoLockout`. |
| `Interrupted` | Baseline, but the lockdown run can stop between any two commands. | F2 breaks `SettledConsistent`, `NoLockout`, `UnconfirmedRestores`. |

## Findings in the current code

Do not weaken a rule or the model to make these pass. Do not change the script unless the user asks.

**F1: `--confirm` can race the rollback it cancels.** The timer fires near the five-minute mark while `--confirm` runs its checks (L182-L184). `systemctl stop` (L185) succeeds, because systemd can keep a fired timer loaded while its service runs, and stopping the timer does not stop `rollback.sh`. Then `--confirm` removes the state directory (L186) while `rollback.sh` runs, and prints "Lockdown confirmed". Depending on where `rollback.sh` is:

- Before L121: `rollback.sh` deletes the drop-in (`rm -f`, L124), then stops at L126. sshd keeps the lockdown live, but the next restart uses the base `sshd_config`.
- Between L121 and L126: the old drop-in (port 2200) is back on disk, UFW allows only port 22. The next sshd restart or reboot locks the user out.
- After L126: `cat` fails inside `[[ ]]` at L127, which `set -e` ignores, so it runs `ufw disable`. The firewall is off and sshd restarts on the old config.

The bash part of each branch was replayed against the real `rollback.sh` text with stub `ufw` and `systemctl` (bash 3.2). Not proved: whether `systemctl stop` on the fired transient timer exits `0` (`Baseline` assumes it fails; `TimerStillLoaded` allows both). Check that on a systemd host before you call F1 confirmed.

**F2: an interrupt inside `rollback_now` removes the safety net.** `apply_lockdown` fails (for example, `systemctl restart sshd` at L162). `rollback_now` stops the timer (L144) and then runs `rollback.sh` (L145). If the run stops between the two (Ctrl-C after the "Lockdown failed" message, or the first SSH session drops), nothing restores the drop-in on disk, and no timer is left. The next sshd restart uses port 22 while UFW still allows only 2200. This is by reading L143-L146; the model shows the shortest path.

## Coverage

- Sync commit: `49c77cb03b1da87ea7286c230643e2e1f64c3bfb` (2026-09-24). `spec/expected.json` records the SHA-256 of `scripts/server-lockdown-tailscale.sh` at that commit. `run` warns when the file differs.
- Covered: `prepare_rollback` (L98-L141), the `rollback.sh` heredoc (L117-L134), `rollback_now` (L143-L146), `apply_lockdown` (L148-L172), `confirm_lockdown` (L174-L188), `main` (L190-L212). Each model action names its lines.
- Abstracted: `assert_sshd_policy`, `assert_listener`, and `assert_ufw_policy` become checks on the model state (drop-in on disk, running sshd port, live UFW). The files in `/run/dotfiles-ssh-lockdown` are one unit. UFW has four states: prior, partial (L164-L169 done), lock, off.
- Not covered: `validate_session`, `scripts/lib/tailnet-access.sh`, `bootstrap-vps.sh`, sshd key and auth behavior, IPv6 rules, and the exact parsing in `public_ssh_rule_present`.

Assumptions:

- One lockdown run at a time (the L99 check and L103 `install -d` are not atomic).
- `apply_lockdown` and `rollback_now` finish within five minutes, so the timer fires only after the run ends.
- No reboot while a lockdown is pending (the usage text forbids it; `/run` and the transient timer do not survive it).
- Restore commands in `rollback.sh` succeed when their files exist.
- The prior firewall lets the prior SSH port in over Tailscale.

## When a change touches covered code

1. Run `"$CHECK" --source <checkout> run` before you change anything, and keep the result.
2. Read the diff of the covered functions. For each changed command, find the model action with that line comment in `spec/SshLockdown.tla`.
3. Change the model from the code first: one command is one action, and a new branch or a new failure is a new disjunct. Update the line comments. Do not shape the model by what makes the check pass.
4. Run `run`, then `mutants`. A mutant marked `STALE` points at model text that you changed: update its `old` and `new` so it still mirrors the same break.
5. A result marked `CHANGED`:
   - A pass that became a violation is a bug candidate. Read the trace (`trace SCENARIO RULE`), tell it as steps in the script's words, and replay the bash part against the real script text with stubs before you call it a bug. If the replay disagrees, the model is wrong: fix the model, not the rule.
   - A violation that became a pass, after a change meant to fix F1 or F2, is a fix. Update that scenario in `spec/expected.json`.
6. Change a rule only when the script's promise changed on purpose, and cite the evidence (usage text, commit message, docs).
7. After the model again describes the code, update `covered.sync_commit` and the SHA-256 in `spec/expected.json`, and this file's line references.

When the pstack plugin is installed, read each TLC result with its `statechart` skill (`/pstack:statechart` in Claude Code). It tells each violation as a short path in plain words, and charts the passing state space. Start it from a copy of `spec/SshLockdown.tla`, outside the repo.

## Files

- `spec/SshLockdown.tla`: the model and the four rules.
- `spec/*.cfg`: scenario constants. The helper adds `SPECIFICATION`, `TypeOK`, and one rule per TLC run.
- `spec/expected.json`: coverage record, expected result for each scenario and rule, findings, and mutants.
- `scripts/check-ssh-lockdown`: the helper (Python 3, standard library only).
