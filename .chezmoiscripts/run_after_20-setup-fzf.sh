#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

# State tracking with version validation fallback
if should_skip_state "fzf-setup"; then
    if is_installed fzf; then
        vecho "fzf setup already completed (state tracked)"
        exit 0
    fi
fi

vecho "Setting up fzf..."
FZF_REPO_PATH="$HOME/.local/share/fzf"
FZF_BIN_PATH="$HOME/.local/bin"
FZF_TARGET="$FZF_BIN_PATH/fzf"
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path 2>/dev/null || true)}"
[ -n "$CHEZMOI_SOURCE_DIR" ] || CHEZMOI_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_VERSION_FILE="$CHEZMOI_SOURCE_DIR/.chezmoiversion.toml"
PINNED_FZF_VERSION=""
if [ -f "$CHEZMOI_VERSION_FILE" ]; then
    PINNED_FZF_VERSION="$(sed -n 's/^fzf = "\([^"]*\)"/\1/p' "$CHEZMOI_VERSION_FILE" | head -1)"
fi

# Check if fzf needs reinstalling (version mismatch or missing)
NEEDS_INSTALL=false
INSTALLED_VERSION=""
if ! is_installed fzf || [ ! -f "$FZF_TARGET" ]; then
    NEEDS_INSTALL=true
else
    INSTALLED_VERSION="$(fzf --version 2>/dev/null | awk '{print $1}')"
fi

if [ "$NEEDS_INSTALL" = "false" ] && [ -f "$FZF_REPO_PATH/install" ]; then
    # Extract version from the install script (format: version=X.Y.Z)
    REPO_VERSION=$(grep '^version=' "$FZF_REPO_PATH/install" 2>/dev/null | head -1 | cut -d= -f2)
    if [ -n "$REPO_VERSION" ] && [ "$REPO_VERSION" != "$INSTALLED_VERSION" ]; then
        vecho "Version mismatch: repo=$REPO_VERSION installed=$INSTALLED_VERSION"
        NEEDS_INSTALL=true
    fi
fi

if [ "$NEEDS_INSTALL" = "false" ] && [ -n "$PINNED_FZF_VERSION" ] && [ "$INSTALLED_VERSION" != "$PINNED_FZF_VERSION" ]; then
    vecho "Version mismatch: pinned=$PINNED_FZF_VERSION installed=$INSTALLED_VERSION"
    NEEDS_INSTALL=true
fi

if is_force_update && [ "$NEEDS_INSTALL" = "false" ]; then
    if [ -n "$PINNED_FZF_VERSION" ] && [ "$INSTALLED_VERSION" = "$PINNED_FZF_VERSION" ]; then
        vecho "fzf is already at pinned version: $INSTALLED_VERSION"
    else
        eecho "Forcing fzf reinstall to refresh managed assets..."
        NEEDS_INSTALL=true
    fi
fi

if [ "$NEEDS_INSTALL" = "false" ]; then
    vecho "fzf is already installed and configured"
    mark_state "fzf-setup"
    exit 0
fi

# Create bin directory if it doesn't exist
mkdir -p "$FZF_BIN_PATH"

# Verify that chezmoi has properly cloned the repository
if [ ! -d "$FZF_REPO_PATH" ] || [ ! -f "$FZF_REPO_PATH/install" ]; then
    eecho "Error: fzf repository not properly initialized at $FZF_REPO_PATH"
    eecho "This might indicate that chezmoi external file setup hasn't completed yet."
    eecho "Try running 'chezmoi apply --refresh-externals' first."
    exit 1
fi

sync_fzf_repo_tag() {
    local target_tag

    if [ -z "$PINNED_FZF_VERSION" ]; then
        return 0
    fi
    if [ ! -d "$FZF_REPO_PATH/.git" ] || ! is_installed git; then
        return 0
    fi

    target_tag="v${PINNED_FZF_VERSION#v}"
    vecho "Aligning fzf repo to tag ${target_tag}"
    git -C "$FZF_REPO_PATH" fetch --tags --force --quiet origin >/dev/null 2>&1

    if git -C "$FZF_REPO_PATH" rev-parse -q --verify "refs/tags/${target_tag}" >/dev/null 2>&1; then
        git -C "$FZF_REPO_PATH" checkout -f "${target_tag}" >/dev/null 2>&1
        vecho "Checked out fzf tag ${target_tag}"
        return 0
    fi

    eecho "Warning: pinned fzf tag ${target_tag} not found locally after fetch; continuing with current checkout."
    return 0
}

sync_fzf_repo_tag

cd "$FZF_REPO_PATH" || exit 1

# Install binary (suppress output unless verbose)
if [ "$VERBOSE" = "true" ]; then
    ./install --bin
else
    ./install --bin >/dev/null 2>&1
fi

# Create or update symlink
rm -f "$FZF_TARGET"
ln -s "$FZF_REPO_PATH/bin/fzf" "$FZF_TARGET"

# Shell integrations are loaded directly from $FZF_BASE/shell/ in fzf.sh
vecho "fzf shell integrations loaded from repository files"

# Verify installation
if [ ! -x "$FZF_TARGET" ]; then
    eecho "Error: fzf installation failed"
    exit 1
fi

mark_state "fzf-setup"

if [ "$VERBOSE" = "true" ]; then
    FZF_VERSION=$("$FZF_TARGET" --version)
    vecho "fzf setup complete! Version: $FZF_VERSION"
fi
