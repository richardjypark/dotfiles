#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}

# Performance summary for chezmoi setup (always show a minimal summary)
echo ""
echo "=== Chezmoi Setup Complete ==="

# Count how many setup steps were skipped vs executed
STATE_DIR="$HOME/.cache/chezmoi-state"
if [ -d "$STATE_DIR" ]; then
    SKIPPED_COUNT=$(find "$STATE_DIR" -name "*.done" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SKIPPED_COUNT" -gt 0 ]; then
        echo "Optimized: $SKIPPED_COUNT operations skipped"
    fi
else
    echo "First run completed"
fi

# Show verbose mode information
if [ "$VERBOSE" = "true" ]; then
    echo ""
    echo "Tools available:"
    command -v node >/dev/null 2>&1 && echo "  node:   $(node -v 2>/dev/null || echo 'installed')"
    command -v uv >/dev/null 2>&1 && echo "  uv:     $(uv --version 2>/dev/null || echo 'installed')"
    command -v claude >/dev/null 2>&1 && echo "  claude: installed"
    command -v tmux >/dev/null 2>&1 && echo "  tmux:   $(tmux -V 2>/dev/null || echo 'installed')"
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