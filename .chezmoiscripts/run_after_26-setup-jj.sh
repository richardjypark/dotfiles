#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

if state_exists "jj-setup"; then
    vecho "Jujutsu setup already completed (state tracked)"
    exit 0
fi

# Cleanup trap for reliable temp directory removal
TEMP_DIR=""
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

vecho "Setting up Jujutsu (jj)..."

add_to_path "$HOME/.local/bin"

# Fast exit if jj is already installed (but mark state)
if is_installed jj; then
    vecho "Jujutsu is already installed: $(jj --version 2>/dev/null || echo 'installed')"
    mark_state "jj-setup"
    exit 0
fi

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

install_via_package_manager() {
    # Try native package managers first for Linux distros with jj packages
    if [ "$OS" = "Linux" ]; then
        if command -v pacman >/dev/null 2>&1; then
            eecho "Installing Jujutsu via pacman..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged pacman -Sy --noconfirm jujutsu
            else
                run_privileged pacman -Sy --noconfirm --quiet jujutsu >/dev/null 2>&1
            fi
            return 0
        elif command -v zypper >/dev/null 2>&1; then
            eecho "Installing Jujutsu via zypper..."
            if [ "$VERBOSE" = "true" ]; then
                run_privileged zypper install -y jujutsu
            else
                run_privileged zypper install -y jujutsu >/dev/null 2>&1
            fi
            return 0
        fi
    fi
    return 1
}

install_via_homebrew() {
    if is_installed brew; then
        eecho "Installing Jujutsu via Homebrew..."
        if [ "$VERBOSE" = "true" ]; then
            brew install jj
        else
            brew install jj >/dev/null 2>&1
        fi
        return 0
    fi
    return 1
}

install_via_binary() {
    # Download pre-built binary from GitHub releases
    eecho "Installing Jujutsu from pre-built binary..."
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ]; then
        eecho "Refusing to download release binary without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow GitHub release download."
        return 1
    fi

    # Get latest version from GitHub API
    LATEST_VERSION=$(curl -sL https://api.github.com/repos/jj-vcs/jj/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

    if [ -z "$LATEST_VERSION" ]; then
        eecho "Error: Could not determine latest jj version from GitHub API"
        eecho "  This may be due to rate limiting or network issues"
        eecho "  Try: curl -sL https://api.github.com/repos/jj-vcs/jj/releases/latest | grep tag_name"
        return 1
    fi

    vecho "Latest jj version: $LATEST_VERSION"

    # Determine binary name based on OS and architecture
    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64|amd64)
                    BINARY_NAME="jj-v${LATEST_VERSION}-x86_64-unknown-linux-musl.tar.gz"
                    ;;
                aarch64|arm64)
                    BINARY_NAME="jj-v${LATEST_VERSION}-aarch64-unknown-linux-musl.tar.gz"
                    ;;
                *)
                    eecho "Error: Unsupported Linux architecture: $ARCH"
                    return 1
                    ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64|amd64)
                    BINARY_NAME="jj-v${LATEST_VERSION}-x86_64-apple-darwin.tar.gz"
                    ;;
                aarch64|arm64)
                    BINARY_NAME="jj-v${LATEST_VERSION}-aarch64-apple-darwin.tar.gz"
                    ;;
                *)
                    eecho "Error: Unsupported macOS architecture: $ARCH"
                    return 1
                    ;;
            esac
            ;;
        *)
            eecho "Error: Unsupported OS: $OS (expected Linux or Darwin)"
            return 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/jj-vcs/jj/releases/download/v${LATEST_VERSION}/${BINARY_NAME}"
    INSTALL_DIR="$HOME/.local/bin"

    mkdir -p "$INSTALL_DIR"

    # Download and extract (TEMP_DIR cleaned up by trap)
    TEMP_DIR=$(mktemp -d)
    vecho "Downloading from: $DOWNLOAD_URL"

    if curl -fsSL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$TEMP_DIR/jj.tar.gz"; then
        tar -xzf "$TEMP_DIR/jj.tar.gz" -C "$TEMP_DIR"

        # Find and install the jj binary
        if [ -f "$TEMP_DIR/jj" ]; then
            mv "$TEMP_DIR/jj" "$INSTALL_DIR/jj"
            chmod +x "$INSTALL_DIR/jj"
        else
            JJ_ARCHIVE_BIN=""
            for candidate in "$TEMP_DIR"/jj-v"${LATEST_VERSION}"-*/jj; do
                if [ -f "$candidate" ]; then
                    JJ_ARCHIVE_BIN="$candidate"
                    break
                fi
            done
            if [ -n "$JJ_ARCHIVE_BIN" ]; then
                mv "$JJ_ARCHIVE_BIN" "$INSTALL_DIR/jj"
                chmod +x "$INSTALL_DIR/jj"
            else
                # Try to find jj binary in extracted files
                JJ_BIN=$(find "$TEMP_DIR" -name "jj" -type f 2>/dev/null | head -1)
                if [ -n "$JJ_BIN" ]; then
                    mv "$JJ_BIN" "$INSTALL_DIR/jj"
                    chmod +x "$INSTALL_DIR/jj"
                else
                    eecho "Error: Could not find jj binary in downloaded archive"
                    eecho "  Archive contents:"
                    while IFS= read -r line; do
                        eecho "    $line"
                    done < <(find "$TEMP_DIR" -maxdepth 2 -print 2>/dev/null)
                    return 1
                fi
            fi
        fi

        return 0
    else
        eecho "Error: Failed to download jj binary from: $DOWNLOAD_URL"
        eecho "  Check network connectivity and try manually:"
        eecho "  curl -L '$DOWNLOAD_URL' -o /tmp/jj.tar.gz"
        return 1
    fi
}

# Try installation methods in order of preference
if install_via_package_manager; then
    vecho "Installed via native package manager"
elif install_via_homebrew; then
    vecho "Installed via Homebrew"
elif install_via_binary; then
    vecho "Installed via pre-built binary"
else
    eecho "Error: Could not install Jujutsu. Please install manually from https://docs.jj-vcs.dev/latest/install-and-setup/"
    exit 1
fi

# Verify installation
if is_installed jj; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Jujutsu installed successfully"
        jj --version 2>/dev/null || true
    fi
    mark_state "jj-setup"
else
    eecho "Error: Jujutsu installation did not produce a working 'jj' binary."
    eecho "Leaving state unset so setup can retry."
    exit 1
fi

vecho "Jujutsu setup complete!"
