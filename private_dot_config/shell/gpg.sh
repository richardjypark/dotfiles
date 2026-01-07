#!/bin/sh
# GPG configuration - only if gpg is available and we have a TTY
command -v gpgconf >/dev/null 2>&1 || return

# Only configure if we have a TTY (skip in non-interactive/sandbox environments)
if [ -t 0 ]; then
    unset SSH_AGENT_PID
    export GPG_TTY=$(tty)
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

    # Ensure GPG agent config exists with secure timeouts
    GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
    if [ ! -f "$GPG_AGENT_CONF" ]; then
        mkdir -p "$HOME/.gnupg"
        chmod 700 "$HOME/.gnupg"
        cat > "$GPG_AGENT_CONF" << 'EOF'
# Cache passphrase for 1 hour (3600 seconds)
default-cache-ttl 3600
# Maximum cache time: 4 hours
max-cache-ttl 14400
# Enable SSH support
enable-ssh-support
EOF
        chmod 600 "$GPG_AGENT_CONF"
    fi

    gpgconf --launch gpg-agent
fi