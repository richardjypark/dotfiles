#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if should_skip_state "ansible-setup"; then
    vecho "Ansible setup already completed (state tracked)"
    exit 0
fi

vecho "Setting up Ansible..."

add_to_path "$HOME/.local/bin"

# Fast exit if ansible is already installed (but mark state)
if is_installed ansible; then
    vecho "Ansible is already installed: $(ansible --version 2>/dev/null | head -1 || echo 'installed')"
    mark_state "ansible-setup"
    exit 0
fi

# Check if we can run privileged commands
CAN_SUDO=false
if [ "$(id -u)" = 0 ]; then
    CAN_SUDO=true
elif ensure_sudo; then
    CAN_SUDO=true
fi

# Detect OS
OS="$(uname -s)"

install_via_homebrew() {
    if is_installed brew; then
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
            eecho "Installing Ansible via dnf..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged dnf install -y ansible
            else
                run_privileged dnf install -y ansible >/dev/null 2>&1
            fi
            return 0
        elif command -v pacman >/dev/null 2>&1; then
            eecho "Installing Ansible via pacman..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged pacman -S --noconfirm --needed ansible
            else
                run_privileged pacman -S --noconfirm --needed --quiet ansible >/dev/null 2>&1
            fi
            return 0
        elif command -v zypper >/dev/null 2>&1; then
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
    if is_installed pipx; then
        eecho "Installing Ansible via pipx..."
        if [ "$VERBOSE" = "true" ]; then
            pipx install ansible --include-deps
        else
            pipx install ansible --include-deps >/dev/null 2>&1
        fi
        return 0
    fi

    # If pipx not available but uv is, install pipx first then ansible
    if is_installed uv; then
        eecho "Installing pipx via uv, then Ansible..."
        if [ "$VERBOSE" = "true" ]; then
            uv tool install pipx
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
    if is_installed pip3; then
        eecho "Installing Ansible via pip3..."
        if [ "$VERBOSE" = "true" ]; then
            pip3 install --user ansible
        else
            pip3 install --user ansible >/dev/null 2>&1
        fi
        return 0
    elif is_installed pip; then
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
if is_installed ansible; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Ansible installed successfully"
        ansible --version | head -3
    fi
    mark_state "ansible-setup"
else
    eecho "Error: Ansible installation did not produce a working 'ansible' binary."
    eecho "Leaving state unset so setup can retry."
    exit 1
fi

vecho "Ansible setup complete!"
