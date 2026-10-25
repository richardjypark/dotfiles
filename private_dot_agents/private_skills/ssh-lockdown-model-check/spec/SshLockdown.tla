---------------------------- MODULE SshLockdown ----------------------------
(***************************************************************************)
(* Model of scripts/server-lockdown-tailscale.sh. It has one lockdown run, *)
(* the five-minute rollback timer that the run arms, and any number of     *)
(* `--confirm` runs from new SSH sessions. Each action is one command of   *)
(* the script; the comment on it gives the script lines (L<n>). The model  *)
(* treats the files in /run/dotfiles-ssh-lockdown as one unit: stateDir.   *)
(* rollback.sh and --confirm share the flock on                            *)
(* /run/dotfiles-ssh-lockdown.lock: lock.                                  *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
    BasePort,          \* sshd port when no 90-tailscale-lockdown.conf exists
    PriorPort,         \* port in the prior drop-in, when PriorDropin = "prior"
    NewPort,           \* SSH_PORT of this lockdown run
    PriorDropin,       \* "prior" if the drop-in existed before the run, else "none"
    PriorOpen,         \* ports that the prior firewall lets in over Tailscale
    PriorUfwActive,    \* UFW was active before the run
    AllowInterrupt     \* the lockdown run can stop between any two commands

Config == {"none", "prior", "lock"}           \* drop-in or running sshd config
Ufw == {"prior", "partial", "lock", "off"}    \* firewall rules; "off" = disabled
Runners == {"run", "timer"}                   \* who executes rollback.sh

Port(c) == CASE c = "none"  -> BasePort
             [] c = "prior" -> PriorPort
             [] c = "lock"  -> NewPort

\* A new SSH connection over Tailscale reaches sshd running config c
\* through firewall state u.
Reach(c, u) == CASE u = "lock"    -> Port(c) = NewPort
                 [] u = "partial" -> Port(c) = NewPort /\ Port(c) \in PriorOpen
                 [] u = "prior"   -> ~PriorUfwActive \/ Port(c) \in PriorOpen
                 [] u = "off"     -> TRUE

VARIABLES
    dropin,     \* /etc/ssh/sshd_config.d/90-tailscale-lockdown.conf on disk
    sshd,       \* config of the running sshd (read at its last restart)
    ufwDisk,    \* /etc/ufw on disk
    ufwLive,    \* firewall rules in the kernel
    stateDir,   \* /run/dotfiles-ssh-lockdown exists
    lock,       \* holder of the flock: "free", "confirm", "run", "timer"
    timer,      \* transient unit: "none", "armed", "stopped", "fired"
    run,        \* program counter of the lockdown run
    confirm,    \* program counter of the current --confirm run
    rb,         \* program counter of rollback.sh per runner
    confirmed   \* a --confirm run printed "Lockdown confirmed"

vars == <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, timer, run, confirm, rb, confirmed>>

RunDone == {"staged", "failed", "stopped"}
ConfirmDone == {"idle", "failed", "confirmed"}
RbDone == {"idle", "done", "aborted"}

TypeOK ==
    /\ dropin \in Config /\ sshd \in Config
    /\ ufwDisk \in Ufw /\ ufwLive \in Ufw
    /\ stateDir \in BOOLEAN /\ confirmed \in BOOLEAN
    /\ lock \in {"free", "confirm"} \cup Runners
    /\ timer \in {"none", "armed", "stopped", "fired"}
    /\ run \in {"start", "prepared", "armed", "dropin", "policy", "restarted",
                "listening", "rules", "enabled", "rollback_now", "rollback"} \cup RunDone
    /\ confirm \in {"lock", "state", "port", "sshd", "listener", "ufw", "stop", "rm"} \cup ConfirmDone
    /\ rb \in [Runners -> {"lock", "status", "dropin", "ufw", "reload", "restart", "cleanup"} \cup RbDone]

Init ==
    /\ dropin = PriorDropin /\ sshd = PriorDropin
    /\ ufwDisk = "prior" /\ ufwLive = "prior"
    /\ stateDir = FALSE /\ lock = "free" /\ timer = "none"
    /\ run = "start" /\ confirm = "idle"
    /\ rb = [r \in Runners |-> "idle"]
    /\ confirmed = FALSE

\* A process that ends closes its lock file descriptor.
ReleaseBy(who) == lock' = IF lock = who THEN "free" ELSE lock

-----------------------------------------------------------------------------
\* The lockdown run: main L226-L232, prepare_rollback L99-L148,
\* apply_lockdown L159-L183, rollback_now L150-L157.

\* A command in apply_lockdown fails: `|| return 1`, then main L227-L229.
ApplyFails == run' = "rollback_now"

Prepare ==                                   \* L100-L117
    /\ run = "start"
    /\ IF stateDir
         THEN /\ run' = "failed"             \* L100-L103: rollback already pending
              /\ UNCHANGED stateDir
         ELSE /\ stateDir' = TRUE            \* L104-L143: snapshot and rollback.sh
              /\ run' = "prepared"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, lock, timer, confirm, rb, confirmed>>

ArmTimer ==                                  \* L144-L147
    /\ run = "prepared"
    /\ \/ /\ timer' = "armed" /\ run' = "armed" /\ UNCHANGED stateDir      \* systemd-run --on-active=5m
       \/ /\ stateDir' = FALSE /\ run' = "failed" /\ UNCHANGED timer       \* L145-L146: systemd-run failed
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, lock, confirm, rb, confirmed>>

WriteDropin ==                               \* L160-L170
    /\ run = "armed"
    /\ \/ /\ dropin' = "lock" /\ run' = "dropin"
       \/ /\ ApplyFails /\ UNCHANGED dropin
    /\ UNCHANGED <<sshd, ufwDisk, ufwLive, stateDir, lock, timer, confirm, rb, confirmed>>

CheckPolicy ==                               \* L172: assert_sshd_policy reads the files on disk
    /\ run = "dropin"
    /\ IF dropin = "lock" THEN run' = "policy" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, timer, confirm, rb, confirmed>>

RestartSshd ==                               \* L173
    /\ run = "policy"
    /\ \/ /\ sshd' = dropin /\ run' = "restarted"
       \/ /\ ApplyFails /\ UNCHANGED sshd
    /\ UNCHANGED <<dropin, ufwDisk, ufwLive, stateDir, lock, timer, confirm, rb, confirmed>>

CheckListener ==                             \* L174: assert_listener
    /\ run = "restarted"
    /\ IF Port(sshd) = NewPort THEN run' = "listening" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, timer, confirm, rb, confirmed>>

UfwRules ==                                  \* L175-L180: default deny, allow tailscale0, delete public
    /\ run = "listening"
    /\ \/ /\ ufwDisk' = "partial" /\ ufwLive' = IF PriorUfwActive THEN "partial" ELSE ufwLive
          /\ run' = "rules"
       \/ /\ ufwDisk' = "partial" /\ ufwLive' = IF PriorUfwActive THEN "partial" ELSE ufwLive
          /\ ApplyFails                      \* a later command of L175-L179 failed
       \/ /\ ApplyFails /\ UNCHANGED <<ufwDisk, ufwLive>>
    /\ UNCHANGED <<dropin, sshd, stateDir, lock, timer, confirm, rb, confirmed>>

UfwEnable ==                                 \* L181
    /\ run = "rules"
    /\ \/ /\ ufwDisk' = "lock" /\ ufwLive' = "lock" /\ run' = "enabled"
       \/ /\ ApplyFails /\ UNCHANGED <<ufwDisk, ufwLive>>
    /\ UNCHANGED <<dropin, sshd, stateDir, lock, timer, confirm, rb, confirmed>>

CheckUfw ==                                  \* L182: assert_ufw_policy, then L232
    /\ run = "enabled"
    /\ IF ufwLive = "lock" THEN run' = "staged" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, timer, confirm, rb, confirmed>>

RunRollbackNow ==                            \* L152 reads the unit file; L155 runs rollback.sh
    /\ run = "rollback_now"
    /\ timer' = timer                        \* L153-L154: the timer stays armed during the restore
    /\ IF stateDir
         THEN /\ rb' = [rb EXCEPT !["run"] = "lock"] /\ run' = "rollback"
         ELSE /\ run' = "failed" /\ UNCHANGED rb
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, confirm, confirmed>>

RollbackNowDone ==                           \* L156: systemctl stop ... || true; then L230
    /\ run = "rollback"
    /\ \/ /\ rb["run"] = "done"
          /\ timer' \in IF timer = "armed" THEN {"stopped", "armed"} ELSE {timer}
       \/ /\ rb["run"] = "aborted"           \* set -e: rollback.sh failed, the run ends here
          /\ UNCHANGED timer
    /\ run' = "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, confirm, rb, confirmed>>

Interrupt ==                                 \* Ctrl-C, or the first SSH session drops
    /\ AllowInterrupt
    /\ run \notin RunDone
    /\ run' = "stopped"
    /\ rb' = [rb EXCEPT !["run"] = IF @ \in RbDone THEN @ ELSE "aborted"]
    /\ ReleaseBy("run")
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, confirmed>>

RunStep == Prepare \/ ArmTimer \/ WriteDropin \/ CheckPolicy \/ RestartSshd
           \/ CheckListener \/ UfwRules \/ UfwEnable \/ CheckUfw
           \/ RunRollbackNow \/ RollbackNowDone

-----------------------------------------------------------------------------
\* The timer. Assumption: apply_lockdown and rollback_now finish within five
\* minutes, so the timer fires only after the run has ended.

TimerFires ==
    /\ timer = "armed"
    /\ run \in RunDone
    /\ timer' = "fired"
    /\ rb' = [rb EXCEPT !["timer"] = IF stateDir THEN "lock" ELSE "aborted"]
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, run, confirm, confirmed>>

\* rollback.sh (L118-L141), run by runner r. Under `set -e`, a failed
\* command ends it ("aborted"). Bash already holds the open script, so a
\* removed state directory does not stop a script that has started.

RbLock(r) ==                                 \* L124-L126
    /\ rb[r] = "lock"
    /\ lock = "free"                         \* L124-L125: exec 9> ...; flock 9
    /\ IF stateDir                           \* L126: [[ -d "$STATE_DIR" ]] || exit 0
         THEN /\ lock' = r /\ rb' = [rb EXCEPT ![r] = "status"]
         ELSE /\ rb' = [rb EXCEPT ![r] = "done"] /\ UNCHANGED lock
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbStatus(r) ==                               \* L127: prior_status="$(cat ...)"
    /\ rb[r] = "status"
    /\ IF stateDir
         THEN /\ rb' = [rb EXCEPT ![r] = "dropin"] /\ UNCHANGED lock
         ELSE /\ rb' = [rb EXCEPT ![r] = "aborted"] /\ ReleaseBy(r)
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbDropin(r) ==                               \* L128-L132
    /\ rb[r] = "dropin"
    /\ dropin' = IF stateDir THEN PriorDropin ELSE "none"
    /\ rb' = [rb EXCEPT ![r] = "ufw"]
    /\ UNCHANGED <<sshd, ufwDisk, ufwLive, stateDir, lock, timer, run, confirm, confirmed>>

RbUfwFiles(r) ==                             \* L133: cp -a "$STATE_DIR/ufw/." /etc/ufw/
    /\ rb[r] = "ufw"
    /\ IF stateDir
         THEN /\ ufwDisk' = "prior" /\ rb' = [rb EXCEPT ![r] = "reload"] /\ UNCHANGED lock
         ELSE /\ rb' = [rb EXCEPT ![r] = "aborted"] /\ UNCHANGED ufwDisk /\ ReleaseBy(r)
    /\ UNCHANGED <<dropin, sshd, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbUfwReload(r) ==                            \* L134-L138: uses prior_status from L127
    /\ rb[r] = "reload"
    /\ IF PriorUfwActive
         THEN /\ ufwLive' = ufwDisk /\ UNCHANGED ufwDisk   \* ufw reload
         ELSE /\ ufwLive' = "prior" /\ ufwDisk' = "prior"  \* ufw disable
    /\ rb' = [rb EXCEPT ![r] = "restart"]
    /\ UNCHANGED <<dropin, sshd, stateDir, lock, timer, run, confirm, confirmed>>

RbRestart(r) ==                              \* L139
    /\ rb[r] = "restart"
    /\ sshd' = dropin
    /\ rb' = [rb EXCEPT ![r] = "cleanup"]
    /\ UNCHANGED <<dropin, ufwDisk, ufwLive, stateDir, lock, timer, run, confirm, confirmed>>

RbCleanup(r) ==                              \* L141, then the script exits
    /\ rb[r] = "cleanup"
    /\ stateDir' = FALSE
    /\ rb' = [rb EXCEPT ![r] = "done"]
    /\ ReleaseBy(r)
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, timer, run, confirm, confirmed>>

RollbackStep(r) == RbLock(r) \/ RbStatus(r) \/ RbDropin(r) \/ RbUfwFiles(r)
                   \/ RbUfwReload(r) \/ RbRestart(r) \/ RbCleanup(r)

-----------------------------------------------------------------------------
\* A --confirm run: main L221-L224, confirm_lockdown L185-L209. Under
\* `set -e`, a failed check or command ends the run ("failed").

ConfirmFails == confirm' = "failed" /\ ReleaseBy("confirm")

ConfirmStarts ==                             \* the user opens a new SSH session and runs --confirm
    /\ confirm \in {"idle", "failed"}
    /\ Reach(sshd, ufwLive)
    /\ confirm' = "lock"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, lock, timer, run, rb, confirmed>>

ConfirmLock ==                               \* L189-L190: exec 9> "$LOCK_FILE"; flock -w 30 9
    /\ confirm = "lock"
    /\ \/ /\ lock = "free" /\ lock' = "confirm" /\ confirm' = "state"
       \/ /\ lock # "free" /\ confirm' = "failed" /\ UNCHANGED lock   \* waited 30 s
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

CheckState ==                                \* L191-L193
    /\ confirm = "state"
    /\ IF stateDir THEN confirm' = "port" /\ UNCHANGED lock ELSE ConfirmFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

CheckPortAndSession ==                       \* L194-L199: reads port and initial-session files
    /\ confirm = "port"
    /\ IF stateDir THEN confirm' = "sshd" /\ UNCHANGED lock ELSE ConfirmFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmSshd ==                               \* L200: assert_sshd_policy reads the files on disk
    /\ confirm = "sshd"
    /\ IF dropin = "lock" THEN confirm' = "listener" /\ UNCHANGED lock ELSE ConfirmFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmListener ==                           \* L201: assert_listener
    /\ confirm = "listener"
    /\ IF Port(sshd) = NewPort THEN confirm' = "ufw" /\ UNCHANGED lock ELSE ConfirmFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmUfw ==                                \* L202: assert_ufw_policy
    /\ confirm = "ufw"
    /\ IF ufwLive = "lock" THEN confirm' = "stop" /\ UNCHANGED lock ELSE ConfirmFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmStopTimer ==                          \* L203-L206: systemctl stop ... || true
    /\ confirm = "stop"
    /\ IF stateDir                           \* L203 reads the unit file
         THEN /\ confirm' = "rm" /\ UNCHANGED lock
              /\ timer' \in IF timer = "armed" THEN {"stopped", "armed"} ELSE {timer}
         ELSE /\ ConfirmFails /\ UNCHANGED timer
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, run, rb, confirmed>>

ConfirmRemoveState ==                        \* L207, then L208 and the run exits
    /\ confirm = "rm"
    /\ stateDir' = FALSE
    /\ confirm' = "confirmed"
    /\ confirmed' = TRUE
    /\ ReleaseBy("confirm")
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, timer, run, rb>>

ConfirmStep == ConfirmLock \/ CheckState \/ CheckPortAndSession \/ ConfirmSshd
               \/ ConfirmListener \/ ConfirmUfw \/ ConfirmStopTimer \/ ConfirmRemoveState

-----------------------------------------------------------------------------

Next == RunStep \/ Interrupt \/ TimerFires \/ ConfirmStarts \/ ConfirmStep
        \/ \E r \in Runners : RollbackStep(r)

\* Strong fairness for rollback.sh: a process that waits in flock gets the
\* lock when it is free again. Linux wakes the waiter at once, and a new
\* --confirm takes a person seconds to type. With weak fairness, endless
\* --confirm retries could keep the lock busy and starve the rollback.
Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(RunStep) /\ WF_vars(TimerFires) /\ WF_vars(ConfirmStep)
        /\ \A r \in Runners : SF_vars(RollbackStep(r))

-----------------------------------------------------------------------------
\* Rules. Settled: no command is running and no timer is armed.

Settled ==
    /\ run \in RunDone
    /\ confirm \in ConfirmDone
    /\ timer # "armed"
    /\ \A r \in Runners : rb[r] \in RbDone

Prior == /\ dropin = PriorDropin /\ sshd = PriorDropin
         /\ ufwDisk = "prior" /\ ufwLive = "prior"

Locked == /\ dropin = "lock" /\ sshd = "lock"
          /\ ufwDisk = "lock" /\ ufwLive = "lock"

\* When --confirm says "Lockdown confirmed", the server runs the lockdown
\* policy, on disk and live.
ConfirmedMeansLocked == Settled /\ confirmed => Locked

\* When everything settles, the server has either its whole prior SSH and
\* firewall configuration or the whole lockdown configuration, not a mix.
SettledConsistent == Settled => Prior \/ Locked

\* When everything settles, a new SSH session over Tailscale can connect
\* now, and also after the next sshd restart or reboot.
NoLockout == Settled => Reach(sshd, ufwLive) /\ Reach(dropin, ufwDisk)

\* If no --confirm run ever succeeds, the prior configuration comes back and
\* stays. (A user can retry --confirm forever, so this rule ignores it.)
UnconfirmedRestores == <>[](~confirmed) => <>[]Prior

=============================================================================
