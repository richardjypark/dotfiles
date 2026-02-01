#!/bin/sh
set -eu

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}
eecho() { echo "$@"; }

# State tracking
STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"
STATE_FILE="$STATE_DIR/ansible-setup.done"

# Fast exit if already completed via state tracking
if [ -f "$STATE_FILE" ]; then
    vecho "Ansible setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Ansible..."

# Ensure ~/.local/bin is in PATH (pipx/uv may install here)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Fast exit if ansible is already installed (but mark state)
if command -v ansible >/dev/null 2>&1; then
    vecho "Ansible is already installed: $(ansible --version 2>/dev/null | head -1 || echo 'installed')"
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    exit 0
fi

# Helper function to run commands with sudo if needed (non-interactively)
run_privileged() {
    if [ "$(id -u)" = 0 ]; then
        "$@"
    elif sudo -n true 2>/dev/null; then
        sudo "$@"
    else
        return 1
    fi
}

# Check if we can run privileged commands
CAN_SUDO=false
if [ "$(id -u)" = 0 ]; then
    CAN_SUDO=true
elif sudo -n true 2>/dev/null; then
    CAN_SUDO=true
fi

# Detect OS
OS="$(uname -s)"

install_via_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        eecho "Installing Ansible via Homebrew..."
        if [ "$VERBOSE" = "true" ]; then
            brew install ansible
        else
            brew install ansible >/dev/null 2>&1
        fi
        return 0
    fi
    return 1
}

install_via_package_manager() {
    # Skip if we don't have passwordless sudo
    if [ "$CAN_SUDO" != "true" ]; then
        return 1
    fi

    if [ "$OS" = "Linux" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            # Debian/Ubuntu
            eecho "Installing Ansible via apt..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged apt-get update
                run_privileged apt-get install -y ansible
            else
                run_privileged apt-get update >/dev/null 2>&1
                run_privileged apt-get install -y ansible >/dev/null 2>&1
            fi
            return 0
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora/RHEL
            eecho "Installing Ansible via dnf..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged dnf install -y ansible
            else
                run_privileged dnf install -y ansible >/dev/null 2>&1
            fi
            return 0
        elif command -v pacman >/dev/null 2>&1; then
            # Arch Linux
            eecho "Installing Ansible via pacman..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged pacman -Sy --noconfirm ansible
            else
                run_privileged pacman -Sy --noconfirm --quiet ansible >/dev/null 2>&1
            fi
            return 0
        elif command -v zypper >/dev/null 2>&1; then
            # openSUSE
            eecho "Installing Ansible via zypper..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged zypper install -y ansible
            else
                run_privileged zypper install -y ansible >/dev/null 2>&1
            fi
            return 0
        fi
    fi
    return 1
}

install_via_pipx() {
    # pipx provides isolated environments, ideal for CLI tools like ansible
    if command -v pipx >/dev/null 2>&1; then
        eecho "Installing Ansible via pipx..."
        if [ "$VERBOSE" = "true" ]; then
            pipx install ansible --include-deps
        else
            pipx install ansible --include-deps >/dev/null 2>&1
        fi
        return 0
    fi

    # If pipx not available but uv is, install pipx first then ansible
    if command -v uv >/dev/null 2>&1; then
        eecho "Installing pipx via uv, then Ansible..."
        if [ "$VERBOSE" = "true" ]; then
            uv tool install pipx
            # Ensure pipx is in PATH
            export PATH="$HOME/.local/bin:$PATH"
            pipx install ansible --include-deps
        else
            uv tool install pipx >/dev/null 2>&1
            export PATH="$HOME/.local/bin:$PATH"
            pipx install ansible --include-deps >/dev/null 2>&1
        fi
        return 0
    fi

    return 1
}

install_via_pip() {
    # Fallback to pip with --user flag
    if command -v pip3 >/dev/null 2>&1; then
        eecho "Installing Ansible via pip3..."
        if [ "$VERBOSE" = "true" ]; then
            pip3 install --user ansible
        else
            pip3 install --user ansible >/dev/null 2>&1
        fi
        return 0
    elif command -v pip >/dev/null 2>&1; then
        eecho "Installing Ansible via pip..."
        if [ "$VERBOSE" = "true" ]; then
            pip install --user ansible
        else
            pip install --user ansible >/dev/null 2>&1
        fi
        return 0
    fi
    return 1
}

# Try installation methods in order of preference
if [ "$OS" = "Darwin" ]; then
    # macOS: prefer Homebrew
    if install_via_homebrew; then
        vecho "Installed via Homebrew"
    elif install_via_pipx; then
        vecho "Installed via pipx"
    elif install_via_pip; then
        vecho "Installed via pip"
    else
        eecho "Error: Could not install Ansible on macOS."
        eecho "  Please install Homebrew first: https://brew.sh"
        exit 1
    fi
else
    # Linux: try package manager first, then pipx, then pip
    if install_via_package_manager; then
        vecho "Installed via native package manager"
    elif install_via_homebrew; then
        vecho "Installed via Homebrew"
    elif install_via_pipx; then
        vecho "Installed via pipx"
    elif install_via_pip; then
        vecho "Installed via pip"
    else
        eecho "Error: Could not install Ansible."
        eecho "  Please install manually: https://docs.ansible.com/ansible/latest/installation_guide/"
        exit 1
    fi
fi

# Verify installation
if command -v ansible >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Ansible installed successfully"
        ansible --version | head -3
    fi
    # Mark setup as complete
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
else
    vecho "Ansible installation complete. You may need to restart your shell."
    # Still mark as complete since installation succeeded
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
fi

vecho "Ansible setup complete!"
