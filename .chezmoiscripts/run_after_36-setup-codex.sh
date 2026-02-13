#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

FORCE_UPDATE="${CHEZMOI_FORCE_UPDATE:-0}"

if state_exists "codex-setup" && [ "$FORCE_UPDATE" != "1" ]; then
    vecho "Codex setup already completed (state tracked)"
    exit 0
fi

# Skip on server role to keep server footprint minimal.
if [ "${CHEZMOI_ROLE:-}" = "server" ]; then
    vecho "Skipping Codex setup on server role"
    exit 0
fi

add_to_path "$HOME/.local/bin"

# Fast exit if codex is already installed and working (but mark state)
# CHEZMOI_FORCE_UPDATE=1 bypasses this for explicit upgrade runs (e.g. czuf)
if [ "$FORCE_UPDATE" != "1" ] && is_installed codex && codex --version >/dev/null 2>&1; then
    vecho "Codex is already installed: $(codex --version 2>/dev/null || echo 'installed')"
    mark_state "codex-setup"
    exit 0
fi

install_via_homebrew() {
    local action="install"

    if ! is_installed brew; then
        return 1
    fi

    if brew list --cask codex >/dev/null 2>&1; then
        # Already installed — check if upgrade is actually needed
        if ! brew outdated --cask codex 2>/dev/null | grep -q codex; then
            eecho "Codex CLI already at latest version (Homebrew)"
            return 0
        fi
        action="upgrade"
    fi

    eecho "Running brew $action for Codex CLI..."
    if [ "$VERBOSE" = "true" ]; then
        if brew "$action" --cask codex; then
            return 0
        fi
    else
        if brew "$action" --cask codex >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

install_via_release_binary() {
    local os arch target latest_version binary_name download_url temp_dir extracted_binary
    if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ] && [ "$FORCE_UPDATE" != "1" ]; then
        eecho "Refusing to download Codex release binary without explicit trust."
        eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow GitHub release download."
        return 1
    fi

    case "$(uname -s)" in
        Linux) os="unknown-linux-musl" ;;
        Darwin) os="apple-darwin" ;;
        *)
            eecho "Unsupported OS for Codex installation: $(uname -s)"
            return 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)
            eecho "Unsupported architecture for Codex installation: $(uname -m)"
            return 1
            ;;
    esac

    target="${arch}-${os}"
    latest_version="$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    if [ -z "$latest_version" ]; then
        eecho "Error: Could not determine latest Codex release version"
        return 1
    fi

    # Compare installed version to latest (tag format: rust-v0.101.0)
    local current_version latest_clean
    current_version="$(codex --version 2>/dev/null | awk '{print $NF}' || true)"
    latest_clean="${latest_version##*v}"  # strip everything up to last 'v'
    if [ -n "$current_version" ] && [ "$current_version" = "$latest_clean" ]; then
        eecho "Codex CLI already at latest version ($current_version)"
        return 0
    fi

    binary_name="codex-${target}.tar.gz"
    download_url="https://github.com/openai/codex/releases/download/${latest_version}/${binary_name}"
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' RETURN

    eecho "Installing Codex CLI from release binary (${latest_version})..."
    if [ "$VERBOSE" = "true" ]; then
        curl -fL --retry 3 --retry-delay 2 "$download_url" -o "$temp_dir/codex.tar.gz"
    else
        curl -fLsS --retry 3 --retry-delay 2 "$download_url" -o "$temp_dir/codex.tar.gz"
    fi

    tar -xzf "$temp_dir/codex.tar.gz" -C "$temp_dir"
    extracted_binary="$(find "$temp_dir" -maxdepth 3 -type f -perm -u+x \
        \( -name "codex" -o -name "codex-${target}" -o -name "codex-*" \) \
        ! -name "*.tar.gz" ! -name "*.zip" ! -name "*.zst" ! -name "*.sigstore" \
        | head -1)"

    if [ -z "$extracted_binary" ]; then
        eecho "Error: Codex binary not found in release archive"
        return 1
    fi

    install -m 755 "$extracted_binary" "$HOME/.local/bin/codex"
    return 0
}

if install_via_homebrew; then
    vecho "Codex installation method: homebrew"
elif install_via_release_binary; then
    vecho "Codex installation method: release binary"
else
    eecho "Error: Could not install Codex CLI via official methods."
    exit 1
fi

# Verify installation
if is_installed codex && codex --version >/dev/null 2>&1; then
    if [ "$VERBOSE" = "true" ]; then
        echo "Codex installed successfully: $(codex --version 2>/dev/null)"
    fi
    mark_state "codex-setup"
else
    eecho "Error: Codex installation failed. Leaving state unset so it can retry."
    exit 1
fi
