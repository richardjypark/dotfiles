#!/bin/sh
# GPG configuration - only if gpg is available and we have a TTY
command -v gpgconf >/dev/null 2>&1 || return

# Only configure if we have a TTY (skip in non-interactive/sandbox environments)
if [ -t 0 ]; then
    unset SSH_AGENT_PID
    export GPG_TTY=$(tty)
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    gpgconf --launch gpg-agent
fi