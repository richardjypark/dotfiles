#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
SERVICE="$REPO_ROOT/private_dot_config/systemd/user/pi-maintenance-agent.service.tmpl"
TIMER="$REPO_ROOT/private_dot_config/systemd/user/pi-maintenance-agent.timer"
GUARD="$REPO_ROOT/.chezmoiscripts/run_after_38-setup-pi-maintenance-agent.sh.tmpl"

grep -Fqx 'ExecStart=/usr/bin/false' "$SERVICE"
grep -Fqx 'RefuseManualStart=yes' "$SERVICE"
grep -Fqx 'RefuseManualStart=yes' "$TIMER"
grep -Fqx 'OnActiveSec=infinity' "$TIMER"
if grep -q '^OnCalendar=' "$TIMER"; then
    printf 'Retired Pi timer still has a calendar event\n' >&2
    exit 1
fi
grep -Fq 'systemctl --user disable --now "$unit"' "$GUARD"
bash -n "$GUARD"
printf 'Retired Pi timer source is inert\n'
