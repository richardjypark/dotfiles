#!/usr/bin/env bash
set -euo pipefail

ROLE=""
DOTFILES_REPO="${DOTFILES_REPO:-richardjypark}"
PRIVATE_ENV_FILE="${PRIVATE_ENV_FILE:-$HOME/.config/dotfiles/bootstrap-private.env}"
TRUST_ON_FIRST_USE_INSTALLERS="${TRUST_ON_FIRST_USE_INSTALLERS:-0}"

usage() {
  cat <<'USAGE'
Usage: bootstrap-omarchy.sh --role workstation|server [--repo <chezmoi-repo>]

Examples:
  ./scripts/bootstrap-omarchy.sh --role workstation
  ./scripts/bootstrap-omarchy.sh --role server --repo richardjypark

Environment:
  PRIVATE_ENV_FILE                   Path to local untracked env file.
  TRUST_ON_FIRST_USE_INSTALLERS      Set to 1 to allow remote installer scripts.
USAGE
}

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --role)
        ROLE="${2:-}"
        shift 2
        ;;
      --repo)
        DOTFILES_REPO="${2:-}"
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

  if [[ "$ROLE" != "workstation" && "$ROLE" != "server" ]]; then
    err "--role must be 'workstation' or 'server'"
    usage
    exit 1
  fi
}

load_private_env() {
  if [[ -f "$PRIVATE_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$PRIVATE_ENV_FILE"
    log "Loaded private env: $PRIVATE_ENV_FILE"
  else
    log "No private env found at $PRIVATE_ENV_FILE (continuing with safe defaults)."
  fi
}

check_arch_linux() {
  if [[ ! -f /etc/os-release ]]; then
    err "/etc/os-release not found"
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *"arch"* ]]; then
    err "This bootstrap targets Omarchy/Arch systems only. Found ID='${ID:-unknown}'."
    exit 1
  fi
}

sudo_refresh_loop() {
  while true; do
    sleep 50
    sudo -n true >/dev/null 2>&1 || exit 0
  done
}

start_sudo_session() {
  sudo -v
  sudo_refresh_loop &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_session() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
  fi
}

install_packages() {
  local -a base_packages=(
    git curl wget zsh tmux openssh tailscale chezmoi
    ripgrep fd bat eza jq
  )

  local -a server_packages=(
    ufw fail2ban
  )

  local -a packages=("${base_packages[@]}")
  if [[ "$ROLE" == "server" ]]; then
    packages+=("${server_packages[@]}")
  fi

  log "Updating system packages..."
  sudo pacman -Syu --noconfirm

  log "Installing bootstrap packages (official repos only)..."
  sudo pacman -S --noconfirm --needed "${packages[@]}"
}

setup_ssh_keys() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    local comment="${BOOTSTRAP_GIT_EMAIL:-${USER}@$(hostname)}"
    log "Generating new SSH keypair at ~/.ssh/id_ed25519"
    ssh-keygen -q -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$comment"
  fi

  if [[ "$ROLE" == "server" ]]; then
    local auth_file="$HOME/.ssh/authorized_keys"
    touch "$auth_file"
    chmod 600 "$auth_file"

    if [[ -n "${BOOTSTRAP_SSH_PUBLIC_KEY_FILE:-}" && -f "${BOOTSTRAP_SSH_PUBLIC_KEY_FILE}" ]]; then
      if ! grep -Fqx "$(cat "$BOOTSTRAP_SSH_PUBLIC_KEY_FILE")" "$auth_file"; then
        cat "$BOOTSTRAP_SSH_PUBLIC_KEY_FILE" >> "$auth_file"
        log "Added server authorized key from BOOTSTRAP_SSH_PUBLIC_KEY_FILE"
      fi
    elif [[ -n "${BOOTSTRAP_SSH_PUBLIC_KEY:-}" ]]; then
      if ! grep -Fqx "$BOOTSTRAP_SSH_PUBLIC_KEY" "$auth_file"; then
        printf '%s\n' "$BOOTSTRAP_SSH_PUBLIC_KEY" >> "$auth_file"
        log "Added server authorized key from BOOTSTRAP_SSH_PUBLIC_KEY"
      fi
    fi

    if ! grep -Fqx "$(cat "$HOME/.ssh/id_ed25519.pub")" "$auth_file"; then
      cat "$HOME/.ssh/id_ed25519.pub" >> "$auth_file"
      log "Added local SSH public key to authorized_keys"
    fi
  fi
}

enable_base_services() {
  sudo systemctl enable --now sshd
  sudo systemctl enable --now tailscaled

  if command -v tailscale >/dev/null 2>&1; then
    sudo tailscale set --operator="$USER" >/dev/null 2>&1 || true
  fi
}

apply_chezmoi_role() {
  export CHEZMOI_ROLE="$ROLE"
  export TRUST_ON_FIRST_USE_INSTALLERS
  export CHEZMOI_BOOTSTRAP_ALLOW_INTERACTIVE_SUDO=1

  if [[ -d "$HOME/.local/share/chezmoi/.git" ]]; then
    log "Applying existing chezmoi source with CHEZMOI_ROLE=$CHEZMOI_ROLE"
    chezmoi apply
  else
    log "Initializing chezmoi source from '$DOTFILES_REPO' with CHEZMOI_ROLE=$CHEZMOI_ROLE"
    chezmoi init --apply "$DOTFILES_REPO"
  fi
}

print_next_steps() {
  cat <<EOF2
Bootstrap complete.

Role: $ROLE
Chezmoi role env: CHEZMOI_ROLE=$ROLE

Next steps:
  1. Join Tailscale if not already connected:
     sudo tailscale up
EOF2

  if [[ "$ROLE" == "server" ]]; then
    cat <<'EOF2'
  2. Verify you can connect to this machine through Tailscale.
  3. Then enforce Tailscale-only SSH:
     sudo ./scripts/server-lockdown-tailscale.sh
EOF2
  fi
}

main() {
  parse_args "$@"
  check_arch_linux
  require_cmd pacman
  require_cmd sudo
  require_cmd systemctl
  require_cmd ssh-keygen

  load_private_env

  trap stop_sudo_session EXIT
  start_sudo_session

  install_packages
  setup_ssh_keys
  enable_base_services
  apply_chezmoi_role
  print_next_steps
}

main "$@"
