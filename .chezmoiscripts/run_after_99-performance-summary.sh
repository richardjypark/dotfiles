#!/usr/bin/env bash
set -euo pipefail

VERBOSE="${VERBOSE:-false}"
STATE_DIR="${STATE_DIR:-$HOME/.cache/chezmoi-state}"

# Performance summary for chezmoi setup (always show a minimal summary)
echo ""
echo "=== Chezmoi Setup Complete ==="

# Count how many setup steps were skipped vs executed
SKIPPED_COUNT=0
if [ -d "$STATE_DIR" ]; then
    set -- "$STATE_DIR"/*.done
    if [ -e "$1" ]; then
        SKIPPED_COUNT=$#
    fi
fi
if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo "Optimized: $SKIPPED_COUNT operations skipped"
else
    echo "First run completed"
fi

if [ "$VERBOSE" != "true" ]; then
    echo "Tip: run chezmoi-health-check for a full environment audit"
    echo ""
    exit 0
fi

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Show verbose mode information
# Prefer NVM default runtime only when we will actually print tool versions.
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.nvm/nvm.sh"
    if command -v nvm >/dev/null 2>&1; then
        NVM_DEFAULT_NODE="$(nvm which default 2>/dev/null || true)"
        if [ -n "$NVM_DEFAULT_NODE" ] && [ -x "$NVM_DEFAULT_NODE" ]; then
            export PATH="$(dirname "$NVM_DEFAULT_NODE"):$PATH"
            hash -r 2>/dev/null || true
        fi
    fi
fi

echo ""
echo "Tools available:"
is_installed node && echo "  node:   $(node -v 2>/dev/null || echo 'installed')"
is_installed uv && echo "  uv:     $(uv --version 2>/dev/null || echo 'installed')"
is_installed claude && echo "  claude: $(claude --version 2>/dev/null || echo 'installed')"
is_installed codex && echo "  codex:  $(codex --version 2>/dev/null || echo 'installed')"
is_installed tmux && echo "  tmux:   $(tmux -V 2>/dev/null || echo 'installed')"
echo ""
echo "Completed at: $(date)"
echo ""
echo "Tips:"
echo "  chezmoi apply --dry-run  # preview changes"
echo "  chezmoi update           # update configs only"
echo "  rm -rf ~/.cache/chezmoi-state  # force full re-run"
echo ""
echo "Chezmoi shortcuts:"
echo "  czu   # fetch + jj rebase + chezmoi apply"
echo "  czuf  # czu + refresh externals/force + trust gate"
echo "  czl   # Omarchy/Arch full maintenance path"
echo "  czm   # macOS full maintenance path"
echo "  czvc  # managed command for chezmoi-check-versions"
echo "  czb   # managed command for chezmoi-bump"
echo "  chezmoi-check-versions  # check pinned dependency versions"
echo "  chezmoi-bump            # bump pinned dependency versions"
echo "  chezmoi-health-check    # full environment audit on demand"
echo ""
echo "Shell replacements (when installed):"
echo "  ls/ll/la/lt  # mapped to eza (or exa fallback)"
echo "  diff         # mapped to delta (or native diff fallback)"
echo ""
