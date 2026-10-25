---------------------------- MODULE SshLockdown ----------------------------
(***************************************************************************)
(* Model of scripts/server-lockdown-tailscale.sh. It has one lockdown run, *)
(* the five-minute rollback timer that the run arms, and any number of     *)
(* `--confirm` runs from new SSH sessions. Each action is one command of   *)
(* the script; the comment on it gives the script lines (L<n>). The model  *)
(* treats the files in /run/dotfiles-ssh-lockdown as one unit: stateDir.   *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
    BasePort,          \* sshd port when no 90-tailscale-lockdown.conf exists
    PriorPort,         \* port in the prior drop-in, when PriorDropin = "prior"
    NewPort,           \* SSH_PORT of this lockdown run
    PriorDropin,       \* "prior" if the drop-in existed before the run, else "none"
    PriorOpen,         \* ports that the prior firewall lets in over Tailscale
    PriorUfwActive,    \* UFW was active before the run
    StopElapsedTimer,  \* exit outcomes of `systemctl stop` on a timer that is not armed
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
    timer,      \* transient unit: "none", "armed", "stopped", "fired"
    run,        \* program counter of the lockdown run
    confirm,    \* program counter of the current --confirm run
    rb,         \* program counter of rollback.sh per runner
    confirmed   \* a --confirm run printed "Lockdown confirmed"

vars == <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, confirm, rb, confirmed>>

RunDone == {"staged", "failed", "stopped"}
ConfirmDone == {"idle", "failed", "confirmed"}
RbDone == {"idle", "done", "aborted"}

TypeOK ==
    /\ dropin \in Config /\ sshd \in Config
    /\ ufwDisk \in Ufw /\ ufwLive \in Ufw
    /\ stateDir \in BOOLEAN /\ confirmed \in BOOLEAN
    /\ timer \in {"none", "armed", "stopped", "fired"}
    /\ run \in {"start", "prepared", "armed", "dropin", "policy", "restarted",
                "listening", "rules", "enabled", "rollback_now", "rollback"} \cup RunDone
    /\ confirm \in {"started", "port", "sshd", "listener", "ufw", "stop", "rm"} \cup ConfirmDone
    /\ rb \in [Runners -> {"dropin", "ufw", "reload", "restart", "cleanup"} \cup RbDone]

Init ==
    /\ dropin = PriorDropin /\ sshd = PriorDropin
    /\ ufwDisk = "prior" /\ ufwLive = "prior"
    /\ stateDir = FALSE /\ timer = "none"
    /\ run = "start" /\ confirm = "idle"
    /\ rb = [r \in Runners |-> "idle"]
    /\ confirmed = FALSE

-----------------------------------------------------------------------------
\* The lockdown run: main L205-L211, prepare_rollback L98-L141,
\* apply_lockdown L148-L172, rollback_now L143-L146.

\* A command in apply_lockdown fails: `|| return 1`, then main L206-L208.
ApplyFails == run' = "rollback_now"

Prepare ==                                   \* L99-L116
    /\ run = "start"
    /\ IF stateDir
         THEN /\ run' = "failed"             \* L99-L101: rollback already pending
              /\ UNCHANGED stateDir
         ELSE /\ stateDir' = TRUE            \* L103-L116: snapshot and rollback.sh
              /\ run' = "prepared"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, timer, confirm, rb, confirmed>>

ArmTimer ==                                  \* L137-L140
    /\ run = "prepared"
    /\ \/ /\ timer' = "armed" /\ run' = "armed" /\ UNCHANGED stateDir      \* systemd-run --on-active=5m
       \/ /\ stateDir' = FALSE /\ run' = "failed" /\ UNCHANGED timer       \* L138-L139: systemd-run failed
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, confirm, rb, confirmed>>

WriteDropin ==                               \* L149-L160
    /\ run = "armed"
    /\ \/ /\ dropin' = "lock" /\ run' = "dropin"
       \/ /\ ApplyFails /\ UNCHANGED dropin
    /\ UNCHANGED <<sshd, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

CheckPolicy ==                               \* L161: assert_sshd_policy reads the files on disk
    /\ run = "dropin"
    /\ IF dropin = "lock" THEN run' = "policy" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

RestartSshd ==                               \* L162
    /\ run = "policy"
    /\ \/ /\ sshd' = dropin /\ run' = "restarted"
       \/ /\ ApplyFails /\ UNCHANGED sshd
    /\ UNCHANGED <<dropin, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

CheckListener ==                             \* L163: assert_listener
    /\ run = "restarted"
    /\ IF Port(sshd) = NewPort THEN run' = "listening" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

UfwRules ==                                  \* L164-L169: default deny, allow tailscale0, delete public
    /\ run = "listening"
    /\ \/ /\ ufwDisk' = "partial" /\ ufwLive' = IF PriorUfwActive THEN "partial" ELSE ufwLive
          /\ run' = "rules"
       \/ /\ ufwDisk' = "partial" /\ ufwLive' = IF PriorUfwActive THEN "partial" ELSE ufwLive
          /\ ApplyFails                      \* a later command of L164-L168 failed
       \/ /\ ApplyFails /\ UNCHANGED <<ufwDisk, ufwLive>>
    /\ UNCHANGED <<dropin, sshd, stateDir, timer, confirm, rb, confirmed>>

UfwEnable ==                                 \* L170
    /\ run = "rules"
    /\ \/ /\ ufwDisk' = "lock" /\ ufwLive' = "lock" /\ run' = "enabled"
       \/ /\ ApplyFails /\ UNCHANGED <<ufwDisk, ufwLive>>
    /\ UNCHANGED <<dropin, sshd, stateDir, timer, confirm, rb, confirmed>>

CheckUfw ==                                  \* L171: assert_ufw_policy, then L211
    /\ run = "enabled"
    /\ IF ufwLive = "lock" THEN run' = "staged" ELSE ApplyFails
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

StopTimerNow ==                              \* L144: systemctl stop ... || true
    /\ run = "rollback_now"
    /\ timer' = IF timer = "armed" THEN "stopped" ELSE timer
    /\ IF stateDir                           \* L145: /bin/bash "$STATE_DIR/rollback.sh"
         THEN /\ rb' = [rb EXCEPT !["run"] = "dropin"] /\ run' = "rollback"
         ELSE /\ run' = "failed" /\ UNCHANGED rb
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, confirm, confirmed>>

RollbackNowDone ==                           \* L209: return 1 after rollback.sh ends
    /\ run = "rollback"
    /\ rb["run"] \in {"done", "aborted"}
    /\ run' = "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, rb, confirmed>>

Interrupt ==                                 \* Ctrl-C, or the first SSH session drops
    /\ AllowInterrupt
    /\ run \notin RunDone
    /\ run' = "stopped"
    /\ rb' = [rb EXCEPT !["run"] = IF @ \in RbDone THEN @ ELSE "aborted"]
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, confirm, confirmed>>

RunStep == Prepare \/ ArmTimer \/ WriteDropin \/ CheckPolicy \/ RestartSshd
           \/ CheckListener \/ UfwRules \/ UfwEnable \/ CheckUfw
           \/ StopTimerNow \/ RollbackNowDone

-----------------------------------------------------------------------------
\* The timer. Assumption: apply_lockdown and rollback_now finish within five
\* minutes, so the timer fires only after the run has ended.

TimerFires ==
    /\ timer = "armed"
    /\ run \in RunDone
    /\ timer' = "fired"
    /\ rb' = [rb EXCEPT !["timer"] = IF stateDir THEN "dropin" ELSE "aborted"]
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, run, confirm, confirmed>>

\* rollback.sh (L117-L134), run by runner r. Under `set -e`, a failed
\* command ends it ("aborted"). Bash already holds the open script, so a
\* removed state directory does not stop a script that has started.

RbDropin(r) ==                               \* L121-L125
    /\ rb[r] = "dropin"
    /\ dropin' = IF stateDir THEN PriorDropin ELSE "none"
    /\ rb' = [rb EXCEPT ![r] = "ufw"]
    /\ UNCHANGED <<sshd, ufwDisk, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbUfwFiles(r) ==                             \* L126: cp -a "$STATE_DIR/ufw/." /etc/ufw/
    /\ rb[r] = "ufw"
    /\ IF stateDir
         THEN /\ ufwDisk' = "prior" /\ rb' = [rb EXCEPT ![r] = "reload"]
         ELSE /\ rb' = [rb EXCEPT ![r] = "aborted"] /\ UNCHANGED ufwDisk
    /\ UNCHANGED <<dropin, sshd, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbUfwReload(r) ==                            \* L127-L131
    /\ rb[r] = "reload"
    /\ IF stateDir /\ PriorUfwActive
         THEN /\ ufwLive' = ufwDisk          \* ufw reload
              /\ UNCHANGED ufwDisk
         ELSE \* ufw disable. A failed cat in [[ ]] does not stop set -e, so a
              \* missing status file also selects this branch.
              /\ ufwLive' = IF PriorUfwActive THEN "off" ELSE "prior"
              /\ ufwDisk' = IF PriorUfwActive THEN "off" ELSE "prior"
    /\ rb' = [rb EXCEPT ![r] = "restart"]
    /\ UNCHANGED <<dropin, sshd, stateDir, timer, run, confirm, confirmed>>

RbRestart(r) ==                              \* L132
    /\ rb[r] = "restart"
    /\ sshd' = dropin
    /\ rb' = [rb EXCEPT ![r] = "cleanup"]
    /\ UNCHANGED <<dropin, ufwDisk, ufwLive, stateDir, timer, run, confirm, confirmed>>

RbCleanup(r) ==                              \* L134
    /\ rb[r] = "cleanup"
    /\ stateDir' = FALSE
    /\ rb' = [rb EXCEPT ![r] = "done"]
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, timer, run, confirm, confirmed>>

RollbackStep(r) == RbDropin(r) \/ RbUfwFiles(r) \/ RbUfwReload(r) \/ RbRestart(r) \/ RbCleanup(r)

-----------------------------------------------------------------------------
\* A --confirm run: main L200-L203, confirm_lockdown L174-L188. Under
\* `set -e`, a failed check or command ends the run ("failed").

ConfirmStarts ==                             \* the user opens a new SSH session and runs --confirm
    /\ confirm \in {"idle", "failed"}
    /\ Reach(sshd, ufwLive)
    /\ confirm' = "started"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

CheckState ==                                \* L175
    /\ confirm = "started"
    /\ confirm' = IF stateDir THEN "port" ELSE "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

CheckPortAndSession ==                       \* L176-L181: reads port and initial-session files
    /\ confirm = "port"
    /\ confirm' = IF stateDir THEN "sshd" ELSE "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmSshd ==                               \* L182: assert_sshd_policy reads the files on disk
    /\ confirm = "sshd"
    /\ confirm' = IF dropin = "lock" THEN "listener" ELSE "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmListener ==                           \* L183: assert_listener
    /\ confirm = "listener"
    /\ confirm' = IF Port(sshd) = NewPort THEN "ufw" ELSE "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmUfw ==                                \* L184: assert_ufw_policy
    /\ confirm = "ufw"
    /\ confirm' = IF ufwLive = "lock" THEN "stop" ELSE "failed"
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, timer, run, rb, confirmed>>

ConfirmStopTimer ==                          \* L185: reads the unit file, then systemctl stop
    /\ confirm = "stop"
    /\ CASE ~stateDir \/ timer = "none" ->   \* no unit file, or a unit that never existed
              /\ confirm' = "failed" /\ UNCHANGED timer
         [] timer = "armed" ->
              /\ timer' = "stopped" /\ confirm' = "rm"
         [] OTHER ->                         \* the timer has fired or was stopped
              \E outcome \in StopElapsedTimer :
                /\ confirm' = IF outcome = "ok" THEN "rm" ELSE "failed"
                /\ UNCHANGED timer
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, stateDir, run, rb, confirmed>>

ConfirmRemoveState ==                        \* L186
    /\ confirm = "rm"
    /\ stateDir' = FALSE
    /\ confirm' = "confirmed"
    /\ confirmed' = TRUE                     \* L187
    /\ UNCHANGED <<dropin, sshd, ufwDisk, ufwLive, timer, run, rb>>

ConfirmStep == CheckState \/ CheckPortAndSession \/ ConfirmSshd \/ ConfirmListener
               \/ ConfirmUfw \/ ConfirmStopTimer \/ ConfirmRemoveState

-----------------------------------------------------------------------------

Next == RunStep \/ Interrupt \/ TimerFires \/ ConfirmStarts \/ ConfirmStep
        \/ \E r \in Runners : RollbackStep(r)

Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(RunStep) /\ WF_vars(TimerFires) /\ WF_vars(ConfirmStep)
        /\ \A r \in Runners : WF_vars(RollbackStep(r))

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
