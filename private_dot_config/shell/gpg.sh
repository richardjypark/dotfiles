#!/bin/sh
# GPG configuration
unset SSH_AGENT_PID
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent