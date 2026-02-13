#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

FORCE_UPDATE="${CHEZMOI_FORCE_UPDATE:-0}"

if state_exists "claude-code-setup" && [ "$FORCE_UPDATE" != "1" ]; then
    vecho "Claude Code setup already completed (state tracked)"
    exit 0
fi

add_to_path "$HOME/.local/bin"

vecho "Setting up Claude Code..."

# Fast exit if claude is already installed and working (but mark state)
# CHEZMOI_FORCE_UPDATE=1 bypasses this for explicit upgrade runs (e.g. czuf)
if [ "$FORCE_UPDATE" != "1" ] && is_installed claude && claude --version >/dev/null 2>&1; then
    vecho "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
    mark_state "claude-code-setup"
    exit 0
fi

if [ "$FORCE_UPDATE" = "1" ]; then
    eecho "Updating Claude Code via official installer..."
else
    eecho "Installing Claude Code via official installer..."
fi
if [ "$TRUST_ON_FIRST_USE_INSTALLERS" != "1" ] && [ "$FORCE_UPDATE" != "1" ]; then
    eecho "Refusing to run remote installer without explicit trust."
    eecho "Re-run with TRUST_ON_FIRST_USE_INSTALLERS=1 to allow claude.ai/install.sh."
    exit 1
fi
if [ "$VERBOSE" = "true" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
else
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1
fi

# Verify installation
if is_installed claude && claude --version >/dev/null 2>&1; then
    eecho "Claude Code installed successfully: $(claude --version 2>/dev/null)"
    mark_state "claude-code-setup"
else
    eecho "Error: Claude Code installation failed. Leaving state unset so it can retry."
    exit 1
fi
