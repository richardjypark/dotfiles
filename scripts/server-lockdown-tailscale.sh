#!/usr/bin/env bash
set -euo pipefail

SSH_PORT="${SSH_PORT:-22}"

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: sudo server-lockdown-tailscale.sh

Environment:
  SSH_PORT   SSH port to harden (default: 22)

Safety:
  Run only after confirming Tailscale SSH access from another session.
  Keep your current root shell open until post-checks pass.

Rollback (if you lock yourself out of Tailscale):
  ufw allow 22/tcp && ufw reload
  rm -f /etc/ssh/sshd_config.d/90-tailscale-lockdown.conf && systemctl restart sshd
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root (sudo ./scripts/server-lockdown-tailscale.sh)."
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

verify_tailscale_ready() {
  if ! ip link show tailscale0 >/dev/null 2>&1; then
    err "tailscale0 interface not found. Connect to Tailscale first."
    exit 1
  fi

  if ! tailscale status --self >/dev/null 2>&1; then
    err "tailscale daemon is not ready. Run 'tailscale up' first."
    exit 1
  fi
}

write_sshd_hardening_dropin() {
  mkdir -p /etc/ssh/sshd_config.d

  cat > /etc/ssh/sshd_config.d/90-tailscale-lockdown.conf <<EOF2
# Managed by scripts/server-lockdown-tailscale.sh
Port ${SSH_PORT}

PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

# Optional but explicit: no trust forwarding on hardened server
AllowAgentForwarding no
X11Forwarding no
EOF2

  sshd -t
  systemctl restart sshd
}

configure_ufw_tailscale_only_ssh() {
  if ! command -v ufw >/dev/null 2>&1; then
    log "ufw is not installed, installing it now..."
    if command -v pacman >/dev/null 2>&1; then
      pacman -S --noconfirm --needed ufw
    else
      err "ufw missing and pacman unavailable"
      exit 1
    fi
  fi

  ufw default deny incoming
  ufw default allow outgoing

  ufw delete allow "${SSH_PORT}/tcp" >/dev/null 2>&1 || true
  ufw allow in on tailscale0 to any port "${SSH_PORT}" proto tcp

  ufw --force enable
}

main() {
  require_root
  require_cmd sshd
  require_cmd systemctl
  require_cmd tailscale
  require_cmd ip

  verify_tailscale_ready

  # Safety guard: enforce lock-down only when tailscale0 is up.
  # Keep your current root shell open so rollback commands remain available.
  write_sshd_hardening_dropin
  configure_ufw_tailscale_only_ssh

  log "Lockdown complete: SSH is now restricted to tailscale0 on port ${SSH_PORT}."
}

main "$@"
