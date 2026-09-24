#!/bin/sh
# Keep GnuPG terminal selection independent of the SSH agent socket.
if command -v gpgconf >/dev/null 2>&1 && [ -t 0 ]; then
    GPG_TTY="$(tty)"
    export GPG_TTY
fi
