#!/bin/sh
# Keep a working inherited or forwarded agent, even when it has no keys.
command -v ssh-add >/dev/null 2>&1 || return 0

ssh_agent_reachable() {
    [ -n "${SSH_AUTH_SOCK:-}" ] || return 1
    ssh-add -l >/dev/null 2>&1
    case "$?" in 0|1) return 0 ;; *) return 1 ;; esac
}

if ! ssh_agent_reachable; then
    if [ "${DOTFILES_SSH_AGENT:-}" = gpg ]; then
        if command -v gpgconf >/dev/null 2>&1; then
            gpgconf --launch gpg-agent >/dev/null 2>&1
            SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
            export SSH_AUTH_SOCK
        fi
    elif [ "$(uname -s)" = Darwin ] && command -v launchctl >/dev/null 2>&1; then
        session_sock="$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || true)"
        if [ -n "$session_sock" ]; then
            SSH_AUTH_SOCK="$session_sock"
            export SSH_AUTH_SOCK
        fi
        unset session_sock
    elif [ "$(uname -s)" = Linux ] && command -v ssh-agent >/dev/null 2>&1; then
        ssh_agent_dir="${XDG_RUNTIME_DIR:-$HOME/.cache}/dotfiles-ssh-agent"
        (umask 077 && mkdir -p "$ssh_agent_dir")
        chmod 700 "$ssh_agent_dir"
        SSH_AUTH_SOCK="$ssh_agent_dir/socket"
        export SSH_AUTH_SOCK
        if ! ssh_agent_reachable; then
            [ ! -S "$SSH_AUTH_SOCK" ] || rm -f "$SSH_AUTH_SOCK"
            if ! ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1; then
                sleep 0.1
                ssh_agent_reachable || printf 'Warning: SSH agent is unavailable at %s\n' "$SSH_AUTH_SOCK" >&2
            fi
        fi
        unset ssh_agent_dir
    fi
fi
if [ "${DOTFILES_SSH_AGENT:-}" = gpg ] && ! ssh_agent_reachable; then
    printf 'Warning: GnuPG SSH agent socket is not ready; check your local gpg-agent configuration.\n' >&2
fi
unset -f ssh_agent_reachable
