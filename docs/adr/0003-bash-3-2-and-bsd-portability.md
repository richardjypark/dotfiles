# Scripts run on macOS bash 3.2 and BSD tools

Every workstation script must run under macOS `/bin/bash` 3.2 and BSD userland, and also under bash 5 on Linux. These are the known traps and the patterns we chose:

- **mktemp.** macOS `mktemp` ignores `TMPDIR` unless it gets a template, and sandboxes allow writes only under `TMPDIR`. Always pass `"${TMPDIR:-/tmp}/name.XXXXXXXX"`.
- **Empty arrays under `set -u`.** bash 3.2 fails on an empty `"${array[@]}"`. Use `${array[@]+"${array[@]}"}` (`chezmoi-rerun-script`; guarded by `tests/test_helper_modules.py`).
- **`read` and here-strings.** `read` consumes one line. To keep an empty field, put all values on one line with a non-whitespace delimiter (`IFS='|'`).
- **Non-ASCII literals.** Write glyphs as `$'\xNN'` UTF-8 bytes (statusline branch glyph U+E0A0).
- **Signal traps in forked subshells.** Bash can run a pending trap in a command substitution that forked just after the signal arrived. Only the main process may own snapshots, locks, and rollback. bash 3.2 has no `BASHPID`, so `bump_all_in_main_process` asks a child for its parent PID. bash 5.2 can also fail to parse a trap that runs during a command substitution and exit with status 2; tests send signals at a fixed quiet point so they test rollback, not that bug.
- **Login shell lookup.** Read the shell from the account database (`dscl` on macOS, `getent` on Linux), not `$SHELL`. `chsh` on macOS asks for a password and needs no sudo; elsewhere try `chsh </dev/null` first so a password prompt cannot hang apply.
- **LaunchServices PID reuse.** macOS can give a reused PID a stale app entry, and node then aborts with exit 134 while npm sets `process.title`. `npm_retry_abort` retries once in a new process and writes its notice to stderr so captured npm output stays clean.
