#!/usr/bin/env bash
set -euo pipefail

CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
if [ -z "$CHEZMOI_SOURCE_DIR" ]; then
    CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
fi
# shellcheck disable=SC1090
. "$CHEZMOI_SOURCE_DIR/scripts/lib/load-helpers.sh"

if ! command -v should_skip_state >/dev/null 2>&1; then
    should_skip_state() {
        local state_name="$1"
        if state_exists "$state_name" && ! is_force_update; then
            return 0
        fi
        return 1
    }
fi

PINNED_CHEZMOI_VERSION="${PINNED_CHEZMOI_VERSION:-2.69.4}"
PINNED_CHEZMOI_LINUX_X86_64_SHA="${PINNED_CHEZMOI_LINUX_X86_64_SHA:-5054cf09cb2993725f525c8bb6ec3ff8625489ecfc061e019c17e737e7c7057b}"
PINNED_CHEZMOI_LINUX_ARM64_SHA="${PINNED_CHEZMOI_LINUX_ARM64_SHA:-560fb76182a3da7db7d445953cfa82fefbdc59284c8c673bb22363db9122ee4e}"
PINNED_CHEZMOI_MACOS_X86_64_SHA="${PINNED_CHEZMOI_MACOS_X86_64_SHA:-bb4954fe9272663a35a313b0b7f0aa58eed35ef0ef8ea1d698fce40670cc28b2}"
PINNED_CHEZMOI_MACOS_ARM64_SHA="${PINNED_CHEZMOI_MACOS_ARM64_SHA:-690ab2618e44e7a78b0ba2e541951ce3bde59c1cf9bc2d491850e8700607b9d4}"

# State tracking with inline fallback validation
if should_skip_state "prerequisites-setup"; then
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
            run_privileged pacman -S --noconfirm --needed --quiet $MISSING_PACKAGES
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

install_chezmoi_via_package_manager() {
    if command -v brew >/dev/null 2>&1; then
        brew install --quiet chezmoi
        return 0
    fi

    if [ "$CAN_SUDO" != "true" ]; then
        return 1
    fi

    if command -v apt-get >/dev/null 2>&1 && apt-cache show chezmoi >/dev/null 2>&1; then
        run_privileged apt-get install -y -qq chezmoi
        return 0
    fi

    if command -v pacman >/dev/null 2>&1; then
        run_privileged pacman -S --noconfirm --needed --quiet chezmoi
        return 0
    fi

    if command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y -q chezmoi
        return 0
    fi

    if command -v yum >/dev/null 2>&1; then
        run_privileged yum install -y -q chezmoi
        return 0
    fi

    if command -v zypper >/dev/null 2>&1; then
        run_privileged zypper install -y -q chezmoi
        return 0
    fi

    if command -v apk >/dev/null 2>&1; then
        run_privileged apk add --quiet chezmoi
        return 0
    fi

    return 1
}

install_chezmoi_via_pinned_release() {
    local platform archive_name expected_sha download_url cache_file temp_dir chezmoi_bin

    if ! require_trust_for_remote_download "github.com/twpayne/chezmoi"; then
        return 1
    fi

    if ! platform="$(platform_key)"; then
        eecho "Error: unsupported platform for pinned chezmoi install ($(uname -s)/$(uname -m))."
        return 1
    fi

    case "$platform" in
        linux-x86_64)
            archive_name="chezmoi_${PINNED_CHEZMOI_VERSION}_linux_amd64.tar.gz"
            expected_sha="$PINNED_CHEZMOI_LINUX_X86_64_SHA"
            ;;
        linux-arm64)
            archive_name="chezmoi_${PINNED_CHEZMOI_VERSION}_linux_arm64.tar.gz"
            expected_sha="$PINNED_CHEZMOI_LINUX_ARM64_SHA"
            ;;
        macos-x86_64)
            archive_name="chezmoi_${PINNED_CHEZMOI_VERSION}_darwin_amd64.tar.gz"
            expected_sha="$PINNED_CHEZMOI_MACOS_X86_64_SHA"
            ;;
        macos-arm64)
            archive_name="chezmoi_${PINNED_CHEZMOI_VERSION}_darwin_arm64.tar.gz"
            expected_sha="$PINNED_CHEZMOI_MACOS_ARM64_SHA"
            ;;
        *)
            eecho "Error: unsupported platform for pinned chezmoi install: ${platform}"
            return 1
            ;;
    esac

    download_url="https://github.com/twpayne/chezmoi/releases/download/v${PINNED_CHEZMOI_VERSION}/${archive_name}"
    cache_file="${CHEZMOI_DOWNLOAD_CACHE_DIR:-$HOME/.cache/chezmoi-downloads}/chezmoi-${PINNED_CHEZMOI_VERSION}-${platform}.tar.gz"

    mkdir -p "$HOME/.local/bin"
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    download_and_verify "$download_url" "$cache_file" "$expected_sha"
    cp "$cache_file" "$temp_dir/chezmoi.tar.gz"
    tar -xzf "$temp_dir/chezmoi.tar.gz" -C "$temp_dir"

    chezmoi_bin="$(find "$temp_dir" -maxdepth 3 -type f -name chezmoi | head -1)"
    if [ -z "$chezmoi_bin" ]; then
        eecho "Error: chezmoi binary not found in pinned release archive."
        return 1
    fi

    install -m 755 "$chezmoi_bin" "$HOME/.local/bin/chezmoi"
    return 0
}

# Install chezmoi only if not present
if ! is_installed chezmoi; then
    eecho "Installing chezmoi..."
    if install_chezmoi_via_package_manager; then
        vecho "Installed chezmoi via package manager"
    elif install_chezmoi_via_pinned_release; then
        vecho "Installed chezmoi via pinned release artifact"
    else
        eecho "Error: Failed to install chezmoi."
        eecho "Install manually from https://www.chezmoi.io/install/ and re-run chezmoi apply."
        exit 1
    fi
    export PATH="$HOME/.local/bin:$PATH"
else
    vecho "chezmoi is already installed"
fi

mark_state "prerequisites-setup"
vecho "Prerequisites check complete!"
