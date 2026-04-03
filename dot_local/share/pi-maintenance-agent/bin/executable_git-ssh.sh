#!/usr/bin/env bash
set -euo pipefail

SSH_BIN="${SSH_BIN:-$(command -v ssh)}"
USER_SSH_CONFIG="${HOME}/.ssh/config"

if [[ -r "$USER_SSH_CONFIG" ]]; then
  exec "$SSH_BIN" -F "$USER_SSH_CONFIG" "$@"
fi

exec "$SSH_BIN" -F /dev/null "$@"
