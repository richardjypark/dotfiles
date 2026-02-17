#!/usr/bin/env bash
set -euo pipefail

HELPER_PATH="$HOME/.local/lib/chezmoi-helpers.sh"
if [ -f "$HELPER_PATH" ]; then
    . "$HELPER_PATH"
else
    CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
    if [ -n "$CHEZMOI_SOURCE_DIR" ] && [ -f "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" ]; then
        . "$CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh"
    else
        echo "Error: could not locate chezmoi helper library." >&2
        echo "Expected either $HELPER_PATH or $CHEZMOI_SOURCE_DIR/dot_local/private_lib/chezmoi-helpers.sh" >&2
        exit 1
    fi
fi

# State tracking with inline fallback validation
if state_exists "prerequisites-setup"; then
    if is_installed zsh && is_installed git && is_installed curl && is_installed chezmoi; then
        vecho "All essential prerequisites are already installed"
        exit 0
    fi
fi

vecho "Checking prerequisites..."

# Fast exit if all essential tools are already available
if is_installed zsh && is_installed git && is_installed curl && is_installed chezmoi; then
    vecho "All essential prerequisites are already installed"
    mark_state "prerequisites-setup"
    exit 0
fi

# Check if we can run privileged commands
CAN_SUDO=false
if [ "$(id -u)" = 0 ]; then
    CAN_SUDO=true
elif ensure_sudo; then
    CAN_SUDO=true
fi

# Only attempt package installations if we have passwordless sudo rights
if [ "$CAN_SUDO" = "true" ]; then
    # Check if essential packages are missing
    MISSING_PACKAGES=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
        fi
    done

    # Only install if we actually need packages
    if [ -n "$MISSING_PACKAGES" ]; then
        eecho "Installing missing packages:$MISSING_PACKAGES"

        if command -v apt-get >/dev/null 2>&1; then
            run_privileged apt-get update -qq
            run_privileged apt-get install -y -qq $MISSING_PACKAGES
        elif command -v dnf >/dev/null 2>&1; then
            run_privileged dnf install -y -q $MISSING_PACKAGES
        elif command -v yum >/dev/null 2>&1; then
            run_privileged yum install -y -q $MISSING_PACKAGES
        elif command -v pacman >/dev/null 2>&1; then
            run_privileged pacman -S --noconfirm --quiet $MISSING_PACKAGES
        elif command -v zypper >/dev/null 2>&1; then
            run_privileged zypper install -y -q $MISSING_PACKAGES
        elif command -v apk >/dev/null 2>&1; then
            run_privileged apk add --quiet $MISSING_PACKAGES
        elif command -v brew >/dev/null 2>&1; then
            brew install --quiet $MISSING_PACKAGES
        else
            eecho "Warning: No supported package manager found. Please install packages manually:"
            eecho "  $MISSING_PACKAGES"
        fi
    else
        vecho "All required packages are already installed"
    fi
else
    # Check if any packages are actually missing before warning
    MISSING=""
    for pkg in zsh git curl wget make gcc; do
        if ! is_installed "$pkg"; then
            MISSING="$MISSING $pkg"
        fi
    done
    if [ -n "$MISSING" ]; then
        eecho "Note: Cannot install packages without passwordless sudo:$MISSING"
    else
        vecho "All required packages are already installed"
    fi
fi

# Create directories if they don't exist (no root needed)
for dir in "$HOME/.local/bin" "$HOME/.local/share"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        vecho "Created directory: $dir"
    fi
done

# Add .local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    if ! grep -q '\.local/bin' "$HOME/.profile" 2>/dev/null; then
        printf "%s\n" "export PATH=\"\$HOME/.local/bin:\$PATH\"" >>"$HOME/.profile"
        vecho "Added .local/bin to PATH"
    fi
fi

# Install chezmoi only if not present
if ! is_installed chezmoi; then
    eecho "Installing chezmoi..."
    if ! require_trust_for_remote_installer "chezmoi.io/get"; then
        exit 1
    fi
    sh -c "$(curl --fail --location --show-error --silent --proto '=https' --tlsv1.2 https://chezmoi.io/get)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
else
    vecho "chezmoi is already installed"
fi

mark_state "prerequisites-setup"
vecho "Prerequisites check complete!"
