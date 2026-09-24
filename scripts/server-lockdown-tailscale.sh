#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/tailnet-access.sh"

SSH_PORT="${SSH_PORT:-22}"
DROPIN=/etc/ssh/sshd_config.d/90-tailscale-lockdown.conf
STATE_DIR=/run/dotfiles-ssh-lockdown
ROLLBACK_UNIT_PREFIX=dotfiles-ssh-rollback

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: sudo server-lockdown-tailscale.sh [--confirm]

Run from a working SSH session over Tailscale. A local timer restores the old
SSH and UFW configuration after five minutes. Open a NEW Tailscale SSH session
as the same user and run this command with --confirm to cancel that timer.
Keep the first session open until confirmation succeeds.
Do not restart the server while confirmation is pending. The timer is temporary.

Environment:
  SSH_PORT  SSH port to harden (default: 22)
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; return 1; }
}

validate_session() {
  [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || {
    err "SSH_PORT must be between 1 and 65535."; return 1;
  }
  [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]] || {
    err "Run this command with sudo as the intended non-root SSH user."; return 1;
  }
  [[ -n "${SSH_CONNECTION:-}" ]] || {
    err "An SSH session is required to verify the remote access path."; return 1;
  }
  local client_ip="${SSH_CONNECTION%% *}"
  if ! tailnet_client_ip "$client_ip"; then
    err "The current SSH client is not on the Tailscale address range."
    return 1
  fi
  if ! ip link show tailscale0 >/dev/null 2>&1 || ! tailscale status --self >/dev/null 2>&1; then
    err "tailscale0 or the Tailscale daemon is not ready."
    return 1
  fi
}

assert_sshd_policy() {
  local effective root_effective
  sshd -t || return 1
  effective="$(sshd -T -C "user=$SUDO_USER,host=localhost,addr=${SSH_CONNECTION%% *}")" || return 1
  grep -Eq '^passwordauthentication no$' <<< "$effective" &&
    grep -Eq '^kbdinteractiveauthentication no$' <<< "$effective" &&
    grep -Eq '^pubkeyauthentication yes$' <<< "$effective" &&
    grep -Eq '^permitrootlogin no$' <<< "$effective" &&
    grep -Eq "^port $SSH_PORT$" <<< "$effective" || {
      err "Effective SSH policy differs from the candidate. Check earlier includes and Match rules."
      return 1
    }
  root_effective="$(sshd -T -C "user=root,host=localhost,addr=${SSH_CONNECTION%% *}")" || return 1
  grep -Eq '^permitrootlogin no$' <<< "$root_effective" || {
    err "Root login remains enabled in an effective SSH Match rule."
    return 1
  }
}

assert_listener() {
  ss -ltnH | awk -v port="$SSH_PORT" '$4 ~ (":" port "$") {found=1} END {exit !found}' || {
    err "No SSH listener is active on port $SSH_PORT."
    return 1
  }
}

public_ssh_rule_present() {
  ufw status | awk -v port="$SSH_PORT" '
    /ALLOW/ && ($1 == port "/tcp" || $1 == port || $1 == "OpenSSH" || $1 == "Anywhere") && $0 !~ /on tailscale0/ {found=1}
    END {exit !found}'
}

assert_ufw_policy() {
  ufw status | grep -Fqx 'Status: active' || {
    err "UFW is not active."; return 1;
  }
  if public_ssh_rule_present; then
    err "A public SSH UFW rule is still present. Review UFW application, IPv4, and IPv6 rules."
    return 1
  fi
  ufw status | grep -Eq "^${SSH_PORT}/tcp on tailscale0[[:space:]]+ALLOW" || {
    err "The intended Tailscale SSH UFW rule is missing."; return 1;
  }
}

prepare_rollback() {
  if [[ -e "$STATE_DIR" ]]; then
    err "An SSH rollback is already pending at $STATE_DIR. Confirm it or wait for recovery."
    return 1
  fi
  install -d -m 700 "$STATE_DIR"
  cp -a /etc/ufw "$STATE_DIR/ufw"
  if ufw status | grep -Fqx 'Status: active'; then
    printf 'active\n' > "$STATE_DIR/ufw-prior-status"
  else
    printf 'inactive\n' > "$STATE_DIR/ufw-prior-status"
  fi
  if [[ -e "$DROPIN" ]]; then
    cp -p "$DROPIN" "$STATE_DIR/dropin"
  fi
  printf '%s\n' "$SSH_CONNECTION" > "$STATE_DIR/initial-session"
  printf '%s\n' "$SSH_PORT" > "$STATE_DIR/port"
  printf '%s-%s\n' "$ROLLBACK_UNIT_PREFIX" "$$" > "$STATE_DIR/unit"
  cat > "$STATE_DIR/rollback.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DROPIN=/etc/ssh/sshd_config.d/90-tailscale-lockdown.conf
STATE_DIR=/run/dotfiles-ssh-lockdown
if [[ -f "$STATE_DIR/dropin" ]]; then
  cp -p "$STATE_DIR/dropin" "$DROPIN"
else
  rm -f "$DROPIN"
fi
cp -a "$STATE_DIR/ufw/." /etc/ufw/
if [[ "$(cat "$STATE_DIR/ufw-prior-status")" = active ]]; then
  ufw reload
else
  ufw disable
fi
systemctl restart sshd || systemctl restart ssh
printf 'SSH and UFW configuration restored from %s\n' "$STATE_DIR" >&2
rm -rf "$STATE_DIR"
SCRIPT
  chmod 700 "$STATE_DIR/rollback.sh"
  if ! systemd-run --unit="$(cat "$STATE_DIR/unit")" --on-active=5m /bin/bash "$STATE_DIR/rollback.sh"; then
    rm -rf "$STATE_DIR"
    return 1
  fi
}

rollback_now() {
  systemctl stop "$(cat "$STATE_DIR/unit").timer" >/dev/null 2>&1 || true
  /bin/bash "$STATE_DIR/rollback.sh"
}

apply_lockdown() {
  install -d -m 755 /etc/ssh/sshd_config.d || return 1
  cat > "$DROPIN" <<EOF || return 1
# Managed by scripts/server-lockdown-tailscale.sh
Port ${SSH_PORT}
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowAgentForwarding no
X11Forwarding no
EOF
  assert_sshd_policy || return 1
  systemctl restart sshd || systemctl restart ssh || return 1
  assert_listener || return 1
  ufw default deny incoming || return 1
  ufw default allow outgoing || return 1
  ufw allow in on tailscale0 to any port "$SSH_PORT" proto tcp || return 1
  if public_ssh_rule_present; then
    ufw delete allow "${SSH_PORT}/tcp" || return 1
  fi
  ufw --force enable || return 1
  assert_ufw_policy
}

confirm_lockdown() {
  [[ -d "$STATE_DIR" ]] || { err "No pending lockdown was found."; return 1; }
  [[ "$SSH_PORT" = "$(cat "$STATE_DIR/port")" ]] || {
    err "Use SSH_PORT=$(cat "$STATE_DIR/port") for confirmation."; return 1;
  }
  [[ "$SSH_CONNECTION" != "$(cat "$STATE_DIR/initial-session")" ]] || {
    err "Confirm from a new SSH connection, not the original session."; return 1;
  }
  assert_sshd_policy
  assert_listener
  assert_ufw_policy
  systemctl stop "$(cat "$STATE_DIR/unit").timer"
  rm -rf "$STATE_DIR"
  log "Lockdown confirmed from a new Tailscale SSH connection."
}

main() {
  case "${1:-}" in
    -h|--help) usage; return 0 ;;
    ''|--confirm) ;;
    *) usage; return 2 ;;
  esac
  [[ "$EUID" -eq 0 ]] || { err "Run as root with sudo."; return 1; }
  for command_name in sshd systemctl systemd-run tailscale ip ss ufw; do
    require_cmd "$command_name"
  done
  validate_session
  if [[ "${1:-}" = --confirm ]]; then
    confirm_lockdown
    return
  fi
  prepare_rollback
  if ! apply_lockdown; then
    err "Lockdown failed. Restoring the prior SSH and UFW configuration."
    rollback_now
    return 1
  fi
  log "Lockdown staged. Open a new Tailscale SSH connection and run this command with --confirm within five minutes."
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then main "$@"; fi
