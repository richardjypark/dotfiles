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
        echo "✅ $SKIPPED_COUNT optimized operations skipped"
    fi
else
    echo "📊 First run completed"
fi

# Show verbose mode information
if [ "$VERBOSE" = "true" ]; then
    echo "🕐 Completed at: $(date)"
    echo ""
    echo "💡 Performance Tips:"
    echo "   • Use 'chezmoi apply --dry-run' to preview changes"
    echo "   • Run 'chezmoi update' instead of 'apply' when only updating configs"
    echo "   • Clear state with: rm -rf ~/.cache/chezmoi-state (forces full re-run)"
    echo "   • Enable verbose output: export VERBOSE=true"
else
    echo "💡 Use 'export VERBOSE=true' for detailed output"
fi
echo "" 