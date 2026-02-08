#!/usr/bin/env bash
set -euo pipefail

OPERATOR_USER="${SUDO_USER:-${USER}}"
NF_CONF="/etc/nftables.conf"
SSHD_DROPIN="/etc/ssh/sshd_config.d/90-tailscale-hardening.conf"

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: sudo setup-personal-cloud-tailscale.sh [--operator <user>]

Options:
  --operator <user>  Non-root user allowed to run `tailscale set` without sudo
  -h, --help         Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --operator)
        [[ $# -ge 2 ]] || { err "--operator requires a value"; exit 1; }
        OPERATOR_USER="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root: sudo ./scripts/setup-personal-cloud-tailscale.sh"
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

require_user() {
  id -u "${OPERATOR_USER}" >/dev/null 2>&1 || {
    err "Operator user does not exist: ${OPERATOR_USER}"
    exit 1
  }
}

install_base_packages() {
  if command -v pacman >/dev/null 2>&1; then
    pacman -S --noconfirm --needed tailscale nftables openssh
  else
    err "pacman not found; this script is intended for Arch/Omarchy."
    exit 1
  fi
}

ensure_tailscaled_running() {
  systemctl enable --now tailscaled
}

ensure_tailscale_login_and_ssh() {
  if tailscale ip -4 >/dev/null 2>&1; then
    tailscale set --ssh --accept-dns=true --operator="${OPERATOR_USER}"
  else
    set +e
    tailscale up --ssh --accept-dns=true --operator="${OPERATOR_USER}"
    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      log
      err "tailscale up failed (exit ${rc}). If you were given an auth URL, open it and rerun this script."
      exit $rc
    fi
  fi

  if ! tailscale ip -4 >/dev/null 2>&1; then
    log
    err "Tailscale is still not logged in. Complete login, then rerun this script."
    exit 1
  fi
}

build_nftables_rules() {
  cat <<'EOF'
#!/usr/bin/nft -f

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    ct state established,related accept
    iif "lo" accept
    iifname "tailscale0" accept

    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    tcp dport 22 drop
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
}

backup_file_if_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    cp -a "$path" "${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

write_nftables_rules() {
  local tmp_conf
  tmp_conf="$(mktemp)"

  build_nftables_rules > "${tmp_conf}"
  nft -c -f "${tmp_conf}"

  backup_file_if_exists "${NF_CONF}"
  install -m 0644 "${tmp_conf}" "${NF_CONF}"

  systemctl enable --now nftables
  nft -f "${NF_CONF}"
  rm -f "${tmp_conf}"
}

write_sshd_hardening_dropin() {
  mkdir -p /etc/ssh/sshd_config.d
  backup_file_if_exists "${SSHD_DROPIN}"
  cat > "${SSHD_DROPIN}" <<'EOF'
# Managed by setup-personal-cloud-tailscale.sh
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
EOF

  sshd -t
  systemctl restart sshd
}

print_post_checks() {
  local ts_ip
  ts_ip="$(tailscale ip -4 | head -n1 || true)"
  local host
  host="$(hostname -s)"

  log
  log "Setup complete."
  log "Tailscale IPv4: ${ts_ip:-unavailable}"
  log "Services:"
  systemctl is-active tailscaled nftables sshd | sed 's/^/  - /'

  log
  log "Next: add/update a tailnet SSH ACL in Tailscale admin for this host/user."
  log "Example:"
  cat <<EOF
{
  "ssh": [
    {
      "action": "accept",
      "src": ["you@example.com"],
      "dst": ["${host}"],
      "users": ["${OPERATOR_USER}"]
    }
  ]
}
EOF
}

main() {
  parse_args "$@"
  require_root
  require_cmd systemctl
  require_user

  install_base_packages
  require_cmd tailscale
  require_cmd nft
  require_cmd sshd
  ensure_tailscaled_running
  ensure_tailscale_login_and_ssh
  write_nftables_rules
  write_sshd_hardening_dropin
  print_post_checks
}

main "$@"
