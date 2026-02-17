#!/usr/bin/env bash
set -euo pipefail

# VPS Bootstrap & Hardening Script
# Assumes: Debian/Ubuntu, running as root, SSH keys already on the box.
#
# Usage:
#   USERNAME=rich DOTFILES_REPO=https://github.com/you/dotfiles.git ./bootstrap-vps.sh
#
# Safety:
#   DISABLE_ROOT_LOGIN and LOCK_SSH_TO_TAILSCALE default to 0.
#   Set to 1 only AFTER confirming SSH / Tailscale work.

# --- Configuration (override via environment) --------------------------------

USERNAME="${USERNAME:-rich}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/YOURNAME/dotfiles.git}"
SSH_PORT="${SSH_PORT:-22}"
SWAP_SIZE_MB="${SWAP_SIZE_MB:-2048}"

LOCK_SSH_TO_TAILSCALE="${LOCK_SSH_TO_TAILSCALE:-0}"
DISABLE_ROOT_LOGIN="${DISABLE_ROOT_LOGIN:-0}"
ALLOW_PASSWORDLESS_SUDO="${ALLOW_PASSWORDLESS_SUDO:-0}"
COPY_ROOT_AUTH_KEYS="${COPY_ROOT_AUTH_KEYS:-0}"
TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"

MAX_AUTH_TRIES="${MAX_AUTH_TRIES:-3}"
LOGIN_GRACE_TIME="${LOGIN_GRACE_TIME:-20}"
CLIENT_ALIVE_INTERVAL="${CLIENT_ALIVE_INTERVAL:-300}"
CLIENT_ALIVE_COUNT_MAX="${CLIENT_ALIVE_COUNT_MAX:-2}"

PINNED_CHEZMOI_VERSION="${PINNED_CHEZMOI_VERSION:-2.69.4}"
PINNED_CHEZMOI_AMD64_DEB_SHA256="${PINNED_CHEZMOI_AMD64_DEB_SHA256:-3f2a4c46d7f13a71db417041ec1e165b05a8d1be4e22cd137ac79423aac6770a}"
PINNED_CHEZMOI_ARM64_DEB_SHA256="${PINNED_CHEZMOI_ARM64_DEB_SHA256:-2129b8a1b925d022e42ddd0065c1fde8df361219a682b47aac54ea952922c1da}"

F2B_MAXRETRY="${F2B_MAXRETRY:-3}"
F2B_FINDTIME="${F2B_FINDTIME:-10m}"
F2B_BANTIME="${F2B_BANTIME:-1h}"

export DEBIAN_FRONTEND=noninteractive

# --- Logging & helpers -------------------------------------------------------

LOG_FILE="/var/log/bootstrap.log"
touch "${LOG_FILE}"
chmod 600 "${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

VERBOSE="${VERBOSE:-false}"
vecho() { [[ "${VERBOSE}" == "true" ]] && echo "$@" || true; }

trap 'echo "FAILED at line ${LINENO} in ${FUNCNAME[0]:-main}" >&2' ERR
SECONDS=0

wait_for_apt_lock() {
  local attempts=0
  while fuser /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend \
              /var/lib/apt/lists/lock /var/cache/apt/archives/lock \
              >/dev/null 2>&1; do
    if (( ++attempts >= 30 )); then
      echo "ERROR: apt lock held for too long." >&2
      exit 1
    fi
    vecho "Waiting for apt lock (${attempts}/30)..."
    sleep 10
  done
}

apt_install() {
  wait_for_apt_lock
  apt-get install -y --no-install-recommends "$@"
}

require_trust_for_remote_installer() {
  local installer="$1"
  if [[ "${TRUST_ON_FIRST_USE_INSTALLERS}" != "1" ]]; then
    echo "ERROR: Refusing to run remote installer '${installer}' without explicit trust." >&2
    echo "Set TRUST_ON_FIRST_USE_INSTALLERS=1 to allow this installer." >&2
    exit 1
  fi
}

download_file() {
  local url="$1" dest="$2"
  curl --fail --location --show-error --silent \
    --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 \
    --connect-timeout 10 --max-time 300 \
    "$url" -o "$dest"
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

verify_sha256() {
  local file="$1" expected="$2"
  [[ "$(sha256_file "$file")" == "$expected" ]]
}

# --- Validation --------------------------------------------------------------

validate() {
  [[ "${EUID}" -eq 0 ]] || { echo "ERROR: Must run as root."; exit 1; }

  # shellcheck source=/dev/null
  source /etc/os-release 2>/dev/null || { echo "ERROR: /etc/os-release not found."; exit 1; }
  case "${ID:-}" in
    debian|ubuntu) vecho "Detected: ${PRETTY_NAME:-${ID}}" ;;
    *) echo "ERROR: Unsupported OS '${ID:-unknown}'. Requires Debian/Ubuntu."; exit 1 ;;
  esac

  [[ "${DOTFILES_REPO}" != *"YOURNAME"* ]] || {
    echo "ERROR: Set DOTFILES_REPO to your actual repo URL."; exit 1;
  }

  curl -fsS --max-time 10 https://github.com >/dev/null 2>&1 || {
    echo "ERROR: Cannot reach github.com. Check network."; exit 1;
  }

  vecho "Validation passed"
}

# --- System preparation ------------------------------------------------------

system_update() {
  echo "== System update =="
  wait_for_apt_lock
  apt-get update -y
  apt-get dist-upgrade -y
}

configure_swap() {
  echo "== Swap =="

  if swapon --show | grep -q '/'; then
    vecho "Swap already active"
    return 0
  fi

  local swapfile="/swapfile"
  if [[ ! -f "${swapfile}" ]]; then
    dd if=/dev/zero of="${swapfile}" bs=1M count="${SWAP_SIZE_MB}" status=none
    chmod 600 "${swapfile}"
    mkswap "${swapfile}" >/dev/null
  fi
  swapon "${swapfile}"
  grep -q "${swapfile}" /etc/fstab || echo "${swapfile} none swap sw 0 0" >> /etc/fstab
  vecho "Swap active: ${SWAP_SIZE_MB}MB"
}

configure_locale() {
  echo "== Timezone & locale =="
  timedatectl set-timezone UTC 2>/dev/null || ln -sf /usr/share/zoneinfo/UTC /etc/localtime

  if ! locale -a 2>/dev/null | grep -qi 'en_US.utf8'; then
    apt_install locales
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen en_US.UTF-8
  fi
  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null || true
}

# --- User setup --------------------------------------------------------------

setup_user() {
  echo "== User setup =="

  if ! id -u "${USERNAME}" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "${USERNAME}"
  fi

  apt_install sudo
  usermod -aG sudo "${USERNAME}"

  if [[ "${ALLOW_PASSWORDLESS_SUDO}" == "1" ]]; then
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"
    chmod 440 "/etc/sudoers.d/${USERNAME}"
  else
    rm -f "/etc/sudoers.d/${USERNAME}"
    echo "Passwordless sudo disabled by default (set ALLOW_PASSWORDLESS_SUDO=1 to enable)."
  fi

  # Copy root's SSH keys to the new user (opt-in only)
  if [[ "${COPY_ROOT_AUTH_KEYS}" == "1" ]]; then
    if [[ -f /root/.ssh/authorized_keys ]]; then
      install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "/home/${USERNAME}/.ssh"
      install -m 600 -o "${USERNAME}" -g "${USERNAME}" \
        /root/.ssh/authorized_keys "/home/${USERNAME}/.ssh/authorized_keys"
    else
      echo "WARNING: /root/.ssh/authorized_keys not found."
    fi
  else
    echo "Root SSH key copy disabled by default (set COPY_ROOT_AUTH_KEYS=1 to enable)."
  fi
}

write_security_flags() {
  local state_dir="/home/${USERNAME}/.config/bootstrap"
  local state_file="${state_dir}/security-flags.env"

  install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "${state_dir}"
  cat > "${state_file}" <<EOF
ALLOW_PASSWORDLESS_SUDO=${ALLOW_PASSWORDLESS_SUDO}
COPY_ROOT_AUTH_KEYS=${COPY_ROOT_AUTH_KEYS}
TRUST_ON_FIRST_USE_INSTALLERS=${TRUST_ON_FIRST_USE_INSTALLERS}
EOF
  chown "${USERNAME}:${USERNAME}" "${state_file}"
  chmod 600 "${state_file}"
  vecho "Wrote bootstrap security flags to ${state_file}"
}

ensure_ssh_access() {
  if [[ ! -f "/home/${USERNAME}/.ssh/authorized_keys" ]]; then
    echo "ERROR: /home/${USERNAME}/.ssh/authorized_keys is missing." >&2
    echo "Provide SSH keys before proceeding, or re-run with COPY_ROOT_AUTH_KEYS=1." >&2
    exit 1
  fi
}

# --- SSH hardening -----------------------------------------------------------

harden_sshd() {
  echo "== SSH hardening =="
  apt_install openssh-server

  # Remove weak host keys; ensure Ed25519 + RSA exist
  rm -f /etc/ssh/ssh_host_{dsa,ecdsa}_key{,.pub}
  [[ -f /etc/ssh/ssh_host_ed25519_key ]] || \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" >/dev/null
  [[ -f /etc/ssh/ssh_host_rsa_key ]] || \
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" >/dev/null

  local allow_users="${USERNAME}" root_login="prohibit-password"
  if [[ "${DISABLE_ROOT_LOGIN}" == "1" ]]; then
    root_login="no"
  else
    allow_users="root ${USERNAME}"
  fi

  cat > /etc/ssh/sshd_config.d/99-hardening.conf <<EOF
Port ${SSH_PORT}

# Authentication
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin ${root_login}
AllowUsers ${allow_users}

# Brute-force limits
MaxAuthTries ${MAX_AUTH_TRIES}
LoginGraceTime ${LOGIN_GRACE_TIME}
ClientAliveInterval ${CLIENT_ALIVE_INTERVAL}
ClientAliveCountMax ${CLIENT_ALIVE_COUNT_MAX}

# Host keys
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
EOF

  sshd -t || { echo "ERROR: sshd config invalid."; exit 1; }
  systemctl enable ssh || true
  systemctl restart ssh || systemctl restart sshd || true
}

# --- Firewall ----------------------------------------------------------------

configure_ufw() {
  echo "== Firewall =="
  apt_install ufw

  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"

  if [[ "${LOCK_SSH_TO_TAILSCALE}" == "1" ]]; then
    if ip link show tailscale0 >/dev/null 2>&1; then
      ufw delete allow "${SSH_PORT}/tcp" || true
      ufw allow in on tailscale0 to any port "${SSH_PORT}" proto tcp
    else
      echo "WARNING: LOCK_SSH_TO_TAILSCALE=1 but tailscale0 not found. Keeping SSH open."
    fi
  fi

  if command -v tailscale >/dev/null 2>&1; then
    ufw allow 41641/udp comment "Tailscale"
  fi

  ufw --force enable
}

# --- Kernel hardening --------------------------------------------------------

harden_kernel() {
  echo "== Kernel hardening =="
  cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Reject source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Hide kernel pointers from non-root
kernel.kptr_restrict = 2

# Restrict dmesg to root
kernel.dmesg_restrict = 1

# Protect hardlinks and symlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Protect FIFOs and regular files in world-writable dirs
fs.protected_fifos = 2
fs.protected_regular = 2
EOF
  sysctl --system >/dev/null 2>&1
}

# --- Auto-updates ------------------------------------------------------------

configure_unattended_upgrades() {
  echo "== Auto security updates =="
  apt_install unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  systemctl enable unattended-upgrades || true
}

# --- fail2ban ----------------------------------------------------------------

configure_fail2ban() {
  echo "== fail2ban =="
  apt_install fail2ban
  cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
backend = systemd
maxretry = ${F2B_MAXRETRY}
findtime = ${F2B_FINDTIME}
bantime = ${F2B_BANTIME}
EOF

  # Whitelist Tailscale CGNAT range so fail2ban never bans Tailscale peers
  if command -v tailscale >/dev/null 2>&1; then
    cat > /etc/fail2ban/jail.d/tailscale-whitelist.conf <<'EOF'
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10
EOF
  fi

  systemctl enable fail2ban
  systemctl restart fail2ban
}

# --- Tailscale ---------------------------------------------------------------

install_tailscale() {
  echo "== Tailscale =="
  if command -v tailscale >/dev/null 2>&1; then
    # Ensure the non-root user can manage Tailscale without sudo
    tailscale set --operator="${USERNAME}" 2>/dev/null || true
    vecho "Already installed"
    return 0
  fi

  if apt-cache show tailscale >/dev/null 2>&1; then
    apt_install tailscale
    systemctl enable tailscaled || true
    systemctl start tailscaled || true
    tailscale set --operator="${USERNAME}" 2>/dev/null || true
    echo "Tailscale installed. Run 'tailscale up' to authenticate."
  else
    echo "WARNING: tailscale package not available in apt sources. Install manually and rerun if needed."
  fi
}

# --- Dotfiles ----------------------------------------------------------------

install_dotfiles() {
  echo "== Dotfiles =="
  apt_install git ca-certificates curl

  local chezmoi_bin="/usr/local/bin/chezmoi"

  if [[ ! -x "${chezmoi_bin}" ]]; then
    if apt-cache show chezmoi >/dev/null 2>&1; then
      apt_install chezmoi
      chezmoi_bin="$(command -v chezmoi)"
    else
      require_trust_for_remote_installer "GitHub release package download"
      local arch deb_name deb_sha deb_url deb_path
      arch="$(dpkg --print-architecture)"
      case "$arch" in
        amd64)
          deb_name="chezmoi_${PINNED_CHEZMOI_VERSION}_linux_amd64.deb"
          deb_sha="${PINNED_CHEZMOI_AMD64_DEB_SHA256}"
          ;;
        arm64)
          deb_name="chezmoi_${PINNED_CHEZMOI_VERSION}_linux_arm64.deb"
          deb_sha="${PINNED_CHEZMOI_ARM64_DEB_SHA256}"
          ;;
        *)
          echo "ERROR: Unsupported architecture for pinned chezmoi package: ${arch}" >&2
          return 1
          ;;
      esac
      deb_url="https://github.com/twpayne/chezmoi/releases/download/v${PINNED_CHEZMOI_VERSION}/${deb_name}"
      deb_path="/tmp/${deb_name}"
      download_file "$deb_url" "$deb_path"
      if ! verify_sha256 "$deb_path" "$deb_sha"; then
        echo "ERROR: checksum verification failed for ${deb_name}" >&2
        return 1
      fi
      dpkg -i "$deb_path" || apt-get install -f -y
      rm -f "$deb_path"
      chezmoi_bin="$(command -v chezmoi)"
    fi
    # Installer may ignore -b and put it in ~/.local/bin; move it if so
    if [[ ! -x "${chezmoi_bin}" && -x "${HOME}/.local/bin/chezmoi" ]]; then
      cp "${HOME}/.local/bin/chezmoi" "${chezmoi_bin}"
      chmod 755 "${chezmoi_bin}"
    fi
  fi

  sudo -u "${USERNAME}" -H env "VERBOSE=${VERBOSE}" "TRUST_ON_FIRST_USE_INSTALLERS=${TRUST_ON_FIRST_USE_INSTALLERS}" \
    "${chezmoi_bin}" init --apply --force "${DOTFILES_REPO}"
}

# --- Verification ------------------------------------------------------------

verify() {
  echo "== Verification =="
  local pass=0 fail=0

  check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
      vecho "  [PASS] ${desc}"; (( ++pass ))
    else
      echo "  [FAIL] ${desc}"; (( ++fail ))
    fi
  }

  # Wrap commands that need pipes or || in bash -c
  check "User ${USERNAME} exists"     id -u "${USERNAME}"
  if [[ "${ALLOW_PASSWORDLESS_SUDO}" == "1" ]]; then
    check "Passwordless sudo"         sudo -u "${USERNAME}" sudo -n true
  else
    vecho "  [SKIP] Passwordless sudo check (ALLOW_PASSWORDLESS_SUDO=0)"
  fi
  check "SSH authorized_keys"         test -f "/home/${USERNAME}/.ssh/authorized_keys"
  check "SSHD config valid"           sshd -t
  check "SSHD running"               bash -c "systemctl is-active ssh || systemctl is-active sshd"
  check "UFW active"                  bash -c "ufw status | grep -q 'Status: active'"
  check "fail2ban running"            systemctl is-active fail2ban
  check "fail2ban sshd jail"          fail2ban-client status sshd
  check "Kernel hardening config"     test -f /etc/sysctl.d/99-hardening.conf
  check "Swap active"                 bash -c "swapon --show | grep -q '/'"
  check "Tailscale installed"         bash -c "command -v tailscale"
  check "Dotfiles applied"            sudo -u "${USERNAME}" -H chezmoi status

  echo ""
  echo "  Results: ${pass} passed, ${fail} failed"
  (( fail > 0 )) && echo "  Review failures above." || true
}

# --- Summary -----------------------------------------------------------------

print_summary() {
  local minutes=$(( SECONDS / 60 )) seconds=$(( SECONDS % 60 ))
  local root_status="key-only"
  [[ "${DISABLE_ROOT_LOGIN}" == "1" ]] && root_status="disabled"
  local ts_status="installed (SSH open on all interfaces)"
  [[ "${LOCK_SSH_TO_TAILSCALE}" == "1" ]] && ts_status="SSH locked to tailscale0"

  echo ""
  echo "============================================"
  echo "  Bootstrap complete (${minutes}m ${seconds}s)"
  echo "============================================"
  echo ""
  echo "  User:      ${USERNAME}"
  echo "  SSH port:  ${SSH_PORT}"
  echo "  Root SSH:  ${root_status}"
  echo "  Tailscale: ${ts_status}"
  echo "  NOPASSWD sudo: ${ALLOW_PASSWORDLESS_SUDO}"
  echo "  Copy root keys: ${COPY_ROOT_AUTH_KEYS}"
  echo "  TOFU installers: ${TRUST_ON_FIRST_USE_INSTALLERS}"
  echo ""

  if [[ -f /var/run/reboot-required ]]; then
    echo "  *** REBOOT REQUIRED ***"
    echo ""
  fi

  echo "  Next steps:"
  echo "  1. Test: ssh -p ${SSH_PORT} ${USERNAME}@<this-ip>"
  echo "  2. If that works, re-run with DISABLE_ROOT_LOGIN=1"
  echo "  3. Run 'tailscale up' to join your tailnet"
  echo "  4. Once confirmed, re-run with LOCK_SSH_TO_TAILSCALE=1"
  echo ""
}

# --- Main --------------------------------------------------------------------

main() {
  validate

  system_update
  configure_swap
  configure_locale

  setup_user
  write_security_flags
  ensure_ssh_access

  install_tailscale

  harden_sshd
  configure_ufw
  harden_kernel
  configure_unattended_upgrades
  configure_fail2ban

  install_dotfiles

  verify
  print_summary
}

main "$@"
