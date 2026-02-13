#!/usr/bin/env bash
set -euo pipefail
. "$HOME/.local/lib/chezmoi-helpers.sh"

# Performance summary for chezmoi setup (always show a minimal summary)
echo ""
echo "=== Chezmoi Setup Complete ==="

# Count how many setup steps were skipped vs executed
SKIPPED_COUNT=$(find "$STATE_DIR" -name "*.done" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo "Optimized: $SKIPPED_COUNT operations skipped"
else
    echo "First run completed"
fi

# Show verbose mode information
if [ "$VERBOSE" = "true" ]; then
    echo ""
    echo "Tools available:"
    is_installed node && echo "  node:   $(node -v 2>/dev/null || echo 'installed')"
    is_installed uv && echo "  uv:     $(uv --version 2>/dev/null || echo 'installed')"
    is_installed claude && echo "  claude: installed"
    is_installed codex && echo "  codex:  $(codex --version 2>/dev/null || echo 'installed')"
    is_installed tmux && echo "  tmux:   $(tmux -V 2>/dev/null || echo 'installed')"
    echo ""
    echo "Completed at: $(date)"
    echo ""
    echo "Tips:"
    echo "  chezmoi apply --dry-run  # preview changes"
    echo "  chezmoi update           # update configs only"
    echo "  rm -rf ~/.cache/chezmoi-state  # force full re-run"
else
    echo "Tip: export VERBOSE=true for detailed output"
fi
echo ""
