#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/tailnet-access.sh"

OPERATOR_USER="${SUDO_USER:-${USER:-}}"
ACTION=stage
SSHD_DROPIN=/etc/ssh/sshd_config.d/90-tailscale-hardening.conf
NF_RULES=/etc/nftables.d/dotfiles-ssh.nft
NF_RUNNER=/usr/local/sbin/dotfiles-ssh-nft-apply
NF_UNIT=/etc/systemd/system/dotfiles-ssh-firewall.service
STATE_DIR=/run/dotfiles-personal-cloud-lockdown

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: sudo setup-personal-cloud-tailscale.sh [--operator USER] [--lockdown|--confirm]

First run sets up Tailscale SSH without closing public SSH. Add a tailnet SSH
policy, then open a NEW Tailscale SSH session as the operator. Run --lockdown
there. A local timer restores SSH and nftables after five minutes. Open another
new Tailscale SSH session and run --confirm to cancel the timer.
Keep the first session open. Do not restart the server before confirmation.
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --operator) [[ $# -ge 2 ]] || { err "--operator needs a user"; return 2; }; OPERATOR_USER="$2"; shift 2 ;;
      --lockdown) ACTION=lockdown; shift ;;
      --confirm) ACTION=confirm; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown argument: $1"; usage; return 2 ;;
    esac
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; return 1; }
}

validate_operator() {
  [[ "$EUID" -eq 0 ]] || { err "Run as root with sudo."; return 1; }
  [[ -n "$OPERATOR_USER" && "$OPERATOR_USER" != root ]] || {
    err "A non-root operator user is required."; return 1;
  }
  id -u "$OPERATOR_USER" >/dev/null 2>&1 || {
    err "Operator user does not exist: $OPERATOR_USER"; return 1;
  }
  if [[ "$ACTION" != stage ]]; then
    [[ "${SUDO_USER:-}" = "$OPERATOR_USER" && -n "${SSH_CONNECTION:-}" ]] || {
      err "Run from the operator's Tailscale SSH session with sudo."; return 1;
    }
    local client_ip="${SSH_CONNECTION%% *}"
    tailnet_client_ip "$client_ip" || {
      err "The current SSH client is outside the Tailscale address range."; return 1;
    }
  fi
}

ensure_tailscale() {
  if ! command -v pacman >/dev/null 2>&1; then
    err "This script requires Arch/Omarchy and pacman."; return 1
  fi
  pacman -S --noconfirm --needed tailscale nftables openssh
  systemctl enable --now tailscaled
  if tailscale ip -4 >/dev/null 2>&1; then
    tailscale set --ssh --accept-dns=true --operator="$OPERATOR_USER"
  else
    tailscale up --ssh --accept-dns=true --operator="$OPERATOR_USER" || {
      err "Complete Tailscale login, then rerun this script."; return 1;
    }
  fi
  tailscale ip -4 >/dev/null 2>&1 && tailscale status --self >/dev/null 2>&1 || {
    err "Tailscale is not ready."; return 1;
  }
}

assert_sshd_settings() {
  local effective root_effective
  sshd -t || return 1
  effective="$(sshd -T -C "user=$OPERATOR_USER,host=localhost,addr=${SSH_CONNECTION%% *}")" || return 1
  root_effective="$(sshd -T -C "user=root,host=localhost,addr=${SSH_CONNECTION%% *}")" || return 1
  for expected in 'passwordauthentication no' 'kbdinteractiveauthentication no' 'pubkeyauthentication yes' 'port 22'; do
    grep -Fqx "$expected" <<< "$effective" || { err "Effective SSH setting is wrong: $expected"; return 1; }
  done
  grep -Fqx 'permitrootlogin no' <<< "$root_effective" || {
    err "Root login remains enabled in an effective SSH Match rule."; return 1;
  }
}

assert_access() {
  ip link show tailscale0 >/dev/null 2>&1 || { err "tailscale0 is missing."; return 1; }
  tailscale status --self >/dev/null 2>&1 || { err "Tailscale is not ready."; return 1; }
  assert_sshd_settings || return 1
  ss -ltnH | awk '$4 ~ /:22$/ {found=1} END {exit !found}' || {
    err "No SSH listener is active on port 22."; return 1;
  }
  systemctl is-active dotfiles-ssh-firewall.service >/dev/null 2>&1 || {
    err "The owned nftables service is not active."; return 1;
  }
  nft list chain inet dotfiles_ssh input | grep -Fq 'iifname != "tailscale0" tcp dport 22 drop' || {
    err "The public SSH drop rule is missing."; return 1;
  }
}

snapshot_file() {
  local source="$1" name="$2"
  if [[ -e "$source" ]]; then cp -p "$source" "$STATE_DIR/$name"; fi
}

prepare_rollback() {
  [[ ! -e "$STATE_DIR" ]] || { err "A lockdown is already pending."; return 1; }
  install -d -m 700 "$STATE_DIR"
  snapshot_file "$SSHD_DROPIN" sshd
  snapshot_file "$NF_RULES" rules
  snapshot_file "$NF_RUNNER" runner
  snapshot_file "$NF_UNIT" unit
  if nft list table inet dotfiles_ssh > "$STATE_DIR/table.nft" 2>/dev/null; then
    printf 'present\n' > "$STATE_DIR/table-state"
  else
    printf 'absent\n' > "$STATE_DIR/table-state"
  fi
  if systemctl is-enabled --quiet dotfiles-ssh-firewall.service; then
    printf 'enabled\n' > "$STATE_DIR/unit-prior-state"
  else
    printf 'disabled\n' > "$STATE_DIR/unit-prior-state"
  fi
  printf '%s\n' "$SSH_CONNECTION" > "$STATE_DIR/initial-session"
  printf 'dotfiles-personal-cloud-rollback-%s\n' "$$" > "$STATE_DIR/unit-name"
  cat > "$STATE_DIR/rollback.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
state=/run/dotfiles-personal-cloud-lockdown
restore() {
  if [[ -f "$state/$2" ]]; then cp -p "$state/$2" "$1"; else rm -f "$1"; fi
}
restore /etc/ssh/sshd_config.d/90-tailscale-hardening.conf sshd
restore /etc/nftables.d/dotfiles-ssh.nft rules
restore /usr/local/sbin/dotfiles-ssh-nft-apply runner
systemctl disable --now dotfiles-ssh-firewall.service >/dev/null 2>&1 || true
restore /etc/systemd/system/dotfiles-ssh-firewall.service unit
systemctl daemon-reload
if [[ "$(cat "$state/table-state")" = absent ]]; then
  nft delete table inet dotfiles_ssh 2>/dev/null || true
else
  batch="$(mktemp)"
  printf 'delete table inet dotfiles_ssh\n' > "$batch"
  cat "$state/table.nft" >> "$batch"
  nft -f "$batch"
  rm -f "$batch"
fi
if [[ -f "$state/unit" ]]; then
  if [[ "$(cat "$state/unit-prior-state")" = enabled ]]; then
    systemctl enable dotfiles-ssh-firewall.service
  fi
  systemctl restart dotfiles-ssh-firewall.service
fi
systemctl restart sshd || systemctl restart ssh
printf 'Prior SSH and nftables configuration restored.\n' >&2
rm -rf "$state"
SCRIPT
  chmod 700 "$STATE_DIR/rollback.sh"
  if ! systemd-run --unit="$(cat "$STATE_DIR/unit-name")" --on-active=5m /bin/bash "$STATE_DIR/rollback.sh"; then
    rm -rf "$STATE_DIR"
    return 1
  fi
}

write_owned_firewall() {
  if systemctl is-active --quiet ufw || systemctl is-active --quiet firewalld; then
    err "An active firewall manager is present. Review it before using this nftables rule."
    return 1
  fi
  install -d -m 755 /etc/nftables.d /usr/local/sbin || return 1
  cat > "$NF_RULES" <<'RULES' || return 1
# This table only restricts public SSH. Other firewall and forwarding rules stay in place.
add table inet dotfiles_ssh
add chain inet dotfiles_ssh input { type filter hook input priority -10; policy accept; }
add rule inet dotfiles_ssh input iifname != "tailscale0" tcp dport 22 drop
RULES
  cat > "$NF_RUNNER" <<'RUNNER' || return 1
#!/usr/bin/env bash
set -euo pipefail
batch="$(mktemp)"
trap 'rm -f "$batch"' EXIT
if nft list table inet dotfiles_ssh >/dev/null 2>&1; then
  printf 'delete table inet dotfiles_ssh\n' > "$batch"
fi
cat /etc/nftables.d/dotfiles-ssh.nft >> "$batch"
nft -c -f "$batch"
nft -f "$batch"
RUNNER
  chmod 755 "$NF_RUNNER" || return 1
  cat > "$NF_UNIT" <<'UNIT' || return 1
[Unit]
Description=Restrict public SSH with an owned nftables table
After=nftables.service
PartOf=nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/dotfiles-ssh-nft-apply
ExecReload=/usr/local/sbin/dotfiles-ssh-nft-apply

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload || return 1
  systemctl enable dotfiles-ssh-firewall.service || return 1
  systemctl restart dotfiles-ssh-firewall.service || return 1
}

write_ssh_dropin() {
  install -d -m 755 /etc/ssh/sshd_config.d || return 1
  cat > "$SSHD_DROPIN" <<'SSHD' || return 1
# Managed by setup-personal-cloud-tailscale.sh
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
SSHD
  assert_sshd_settings || return 1
  systemctl restart sshd || systemctl restart ssh || return 1
}

confirm_lockdown() {
  [[ -d "$STATE_DIR" ]] || { err "No pending lockdown was found."; return 1; }
  [[ "$SSH_CONNECTION" != "$(cat "$STATE_DIR/initial-session")" ]] || {
    err "Confirm from a new SSH connection."; return 1;
  }
  assert_access
  systemctl stop "$(cat "$STATE_DIR/unit-name").timer"
  rm -rf "$STATE_DIR"
  log "Public SSH restriction confirmed from a new Tailscale SSH connection."
}

main() {
  parse_args "$@"
  validate_operator
  require_cmd systemctl
  if [[ "$ACTION" = stage ]]; then
    ensure_tailscale
    log "Tailscale SSH is enabled. Set the tailnet SSH policy, then connect in a new Tailscale SSH session and run --lockdown."
    return
  fi
  for command_name in systemd-run tailscale sshd nft ip ss; do require_cmd "$command_name"; done
  ip link show tailscale0 >/dev/null 2>&1 && tailscale status --self >/dev/null 2>&1 || {
    err "Tailscale is not ready."; return 1;
  }
  if [[ "$ACTION" = confirm ]]; then confirm_lockdown; return; fi
  [[ -x "$NF_RUNNER" || ! -e "$NF_RUNNER" ]] || { err "The owned firewall runner is not executable."; return 1; }
  prepare_rollback
  if ! { write_ssh_dropin && write_owned_firewall && assert_access; }; then
    err "Lockdown failed. Restoring the prior SSH and nftables configuration."
    systemctl stop "$(cat "$STATE_DIR/unit-name").timer" >/dev/null 2>&1 || true
    /bin/bash "$STATE_DIR/rollback.sh"
    return 1
  fi
  log "Lockdown staged. Open a new Tailscale SSH session and run --confirm within five minutes."
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then main "$@"; fi
