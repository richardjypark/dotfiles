#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

RALPH_HOME="$HOME/.ralph"

# Only run if ralph is installed
if [ ! -f "$RALPH_HOME/ralph_loop.sh" ]; then
    vecho "Ralph not installed, skipping patches"
    exit 0
fi

vecho "Applying Ralph patches..."

# =============================================================================
# Patch 0: Update CLAUDE_CODE_CMD to skip permissions prompts
# =============================================================================
if [ -f "$RALPH_HOME/ralph_loop.sh" ]; then
    # Check if already patched (look for --dangerously-skip-permissions)
    if ! grep -q 'dangerously-skip-permissions' "$RALPH_HOME/ralph_loop.sh"; then
        vecho "Patching CLAUDE_CODE_CMD to skip permissions..."
        sed -i.bak 's/CLAUDE_CODE_CMD="claude"$/CLAUDE_CODE_CMD="claude --dangerously-skip-permissions"/' "$RALPH_HOME/ralph_loop.sh"
        rm -f "$RALPH_HOME/ralph_loop.sh.bak"
        vecho "CLAUDE_CODE_CMD patched"
    else
        vecho "CLAUDE_CODE_CMD already patched"
    fi
fi

# =============================================================================
# Patch 1: Fix setup.sh to use $RALPH_HOME for template paths
# =============================================================================
if [ -f "$RALPH_HOME/setup.sh" ]; then
    # Check if already patched (look for RALPH_HOME in the file)
    if ! grep -q 'RALPH_HOME=.*\$HOME/.ralph' "$RALPH_HOME/setup.sh"; then
        vecho "Patching setup.sh..."
        cat > "$RALPH_HOME/setup.sh" << 'SETUPEOF'
#!/bin/bash

# Ralph Project Setup Script
set -e

PROJECT_NAME=${1:-"my-project"}
RALPH_HOME="${RALPH_HOME:-$HOME/.ralph}"

echo "🚀 Setting up Ralph project: $PROJECT_NAME"

# Create project directory
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create structure
mkdir -p {specs/stdlib,src,examples,logs,docs/generated}

# Copy templates from Ralph installation directory
cp "$RALPH_HOME/templates/PROMPT.md" .
cp "$RALPH_HOME/templates/fix_plan.md" @fix_plan.md
cp "$RALPH_HOME/templates/AGENT.md" @AGENT.md
cp -r "$RALPH_HOME/templates/specs/"* specs/ 2>/dev/null || true

# Initialize git
git init
echo "# $PROJECT_NAME" > README.md
git add .
git commit -m "Initial Ralph project setup"

echo "✅ Project $PROJECT_NAME created!"
echo "Next steps:"
echo "  1. Edit PROMPT.md with your project requirements"
echo "  2. Update specs/ with your project specifications"
echo "  3. Run: ralph --monitor"
echo "  4. Or just: ralph"
SETUPEOF
        chmod +x "$RALPH_HOME/setup.sh"
        vecho "setup.sh patched"
    else
        vecho "setup.sh already patched"
    fi
fi

# =============================================================================
# Patch 2: Fix ralph_loop.sh tmux session setup to detect existing tmux
# =============================================================================
if [ -f "$RALPH_HOME/ralph_loop.sh" ]; then
    # Check if already patched (look for TMUX detection)
    if ! grep -q 'if \[\[ -n "\$TMUX" \]\]' "$RALPH_HOME/ralph_loop.sh"; then
        vecho "Patching ralph_loop.sh tmux handling..."

        # Use sed to replace the setup_tmux_session function
        # This is complex, so we'll use a marker-based approach

        # Create a temp file with the new function
        mkdir -p /tmp/claude 2>/dev/null || true
        cat > /tmp/claude/ralph_tmux_patch.txt << 'TMUXEOF'
# Setup tmux session with monitor
setup_tmux_session() {
    local ralph_home="${RALPH_HOME:-$HOME/.ralph}"
    local current_dir="$(pwd)"

    # Build ralph command first (exclude tmux flag to avoid recursion)
    local ralph_cmd
    if command -v ralph &> /dev/null; then
        ralph_cmd="ralph"
    else
        ralph_cmd="'$ralph_home/ralph_loop.sh'"
    fi

    if [[ "$MAX_CALLS_PER_HOUR" != "100" ]]; then
        ralph_cmd="$ralph_cmd --calls $MAX_CALLS_PER_HOUR"
    fi
    if [[ "$PROMPT_FILE" != "PROMPT.md" ]]; then
        ralph_cmd="$ralph_cmd --prompt '$PROMPT_FILE'"
    fi

    # Check if already inside tmux
    if [[ -n "$TMUX" ]]; then
        log_status "INFO" "Already inside tmux, splitting current window..."

        # Split current window horizontally (creates pane on right)
        tmux split-window -h -c "$current_dir" "ralph-monitor || '$ralph_home/ralph_monitor.sh'"

        # Select the left pane (will run ralph there)
        tmux select-pane -L

        log_status "SUCCESS" "Monitor started in right pane"
        log_status "INFO" "Use Ctrl+B then arrow keys to switch panes"
        log_status "INFO" "Starting Ralph loop in this pane..."

        # Don't exit - let the script continue to run ralph in current pane
        return 0
    fi

    # Not inside tmux - create new session
    local session_name="ralph-$(date +%s)"
    log_status "INFO" "Setting up tmux session: $session_name"

    # Create session and run ralph in one command
    tmux new-session -d -s "$session_name" -c "$current_dir" "$ralph_cmd"

    # Split and run monitor
    tmux split-window -h -t "$session_name" -c "$current_dir" "ralph-monitor || '$ralph_home/ralph_monitor.sh'"

    # Select the left pane (ralph loop)
    tmux select-pane -t "$session_name" -L

    log_status "SUCCESS" "Tmux session created. Attaching to session..."
    log_status "INFO" "Use Ctrl+B then D to detach from session"
    log_status "INFO" "Use 'tmux attach -t $session_name' to reattach"

    # Attach to session
    tmux attach-session -t "$session_name"

    exit 0
}
TMUXEOF

        # Use awk to replace the function
        awk '
        /^# Setup tmux session with monitor$/ {
            skip = 1
            while ((getline line < "/tmp/claude/ralph_tmux_patch.txt") > 0) {
                print line
            }
            close("/tmp/claude/ralph_tmux_patch.txt")
            next
        }
        /^# Initialize call tracking$/ && skip {
            skip = 0
            print ""
            print $0
            next
        }
        !skip { print }
        ' "$RALPH_HOME/ralph_loop.sh" > "$RALPH_HOME/ralph_loop.sh.tmp"

        mv "$RALPH_HOME/ralph_loop.sh.tmp" "$RALPH_HOME/ralph_loop.sh"
        chmod +x "$RALPH_HOME/ralph_loop.sh"
        rm -f /tmp/claude/ralph_tmux_patch.txt

        vecho "ralph_loop.sh patched"
    else
        vecho "ralph_loop.sh already patched"
    fi
fi

# =============================================================================
# Patch 3: Fix timeout command for macOS compatibility
# =============================================================================
if [ -f "$RALPH_HOME/ralph_loop.sh" ]; then
    # Check if already patched (look for local timeout_cmd detection)
    if ! grep -q 'local timeout_cmd=""' "$RALPH_HOME/ralph_loop.sh"; then
        vecho "Patching ralph_loop.sh timeout handling..."

        # Step 1: Add timeout detection after the timeout_seconds line
        sed -i.bak '/local timeout_seconds=\$((CLAUDE_TIMEOUT_MINUTES \* 60))/a\
\
    # Detect timeout command (gtimeout on macOS via coreutils, timeout on Linux)\
    local timeout_cmd=""\
    if command -v gtimeout \&> /dev/null; then\
        timeout_cmd="gtimeout"\
    elif command -v timeout \&> /dev/null; then\
        timeout_cmd="timeout"\
    fi
' "$RALPH_HOME/ralph_loop.sh"

        # Step 2: Replace the execution line to use conditional timeout
        # Original: if timeout ${timeout_seconds}s $CLAUDE_CODE_CMD ... &
        # New: if [ -n "$timeout_cmd" ]; then $timeout_cmd ... & else ... & fi
        sed -i.bak 's|if timeout \${timeout_seconds}s \$CLAUDE_CODE_CMD < "\$PROMPT_FILE" > "\$output_file" 2>\&1 \&|if [ -n "$timeout_cmd" ]; then\n        $timeout_cmd ${timeout_seconds}s $CLAUDE_CODE_CMD < "$PROMPT_FILE" > "$output_file" 2>\&1 \&\n    else\n        # No timeout available, run without timeout\n        $CLAUDE_CODE_CMD < "$PROMPT_FILE" > "$output_file" 2>\&1 \&\n    fi\n    if true|' "$RALPH_HOME/ralph_loop.sh"

        rm -f "$RALPH_HOME/ralph_loop.sh.bak"
        chmod +x "$RALPH_HOME/ralph_loop.sh"

        vecho "ralph_loop.sh timeout handling patched"
    else
        vecho "ralph_loop.sh timeout already patched"
    fi
fi

# =============================================================================
# Patch 4: Add commit_changes function for auto-committing after each loop
# =============================================================================
if [ -f "$RALPH_HOME/ralph_loop.sh" ]; then
    # Check if already patched (look for commit_changes function)
    if ! grep -q 'commit_changes()' "$RALPH_HOME/ralph_loop.sh"; then
        vecho "Patching ralph_loop.sh with commit_changes function..."

        # Create the commit_changes function
        mkdir -p /tmp/claude 2>/dev/null || true
        cat > /tmp/claude/ralph_commit_patch.txt << 'COMMITEOF'
# Commit changes after successful loop execution
commit_changes() {
    local loop_count=$1

    # Check if jj is available (preferred) or fall back to git
    if command -v jj &> /dev/null; then
        # Check if there are changes to commit
        local changed_files=$(jj diff --stat 2>/dev/null | grep -E "^\s*[0-9]+ file" | head -1)
        if [[ -n "$changed_files" ]]; then
            # Get summary from @fix_plan.md or generate one
            local completed_count=$(grep -c "^\s*- \[x\]" @fix_plan.md 2>/dev/null || echo "0")
            local total_count=$(grep -c "^\s*- \[" @fix_plan.md 2>/dev/null || echo "0")

            # Update commit message with progress
            jj describe -m "wip: Ralph loop #$loop_count ($completed_count/$total_count tasks)" 2>/dev/null
            log_status "SUCCESS" "📝 Committed changes (Loop #$loop_count, $completed_count/$total_count tasks)"
        fi
    elif command -v git &> /dev/null; then
        # Git fallback
        local changed_files=$(git diff --name-only 2>/dev/null | wc -l)
        if [[ $changed_files -gt 0 ]]; then
            local completed_count=$(grep -c "^\s*- \[x\]" @fix_plan.md 2>/dev/null || echo "0")
            local total_count=$(grep -c "^\s*- \[" @fix_plan.md 2>/dev/null || echo "0")

            git add -A 2>/dev/null
            git commit -m "wip: Ralph loop #$loop_count ($completed_count/$total_count tasks)" 2>/dev/null
            log_status "SUCCESS" "📝 Committed changes (Loop #$loop_count, $completed_count/$total_count tasks)"
        fi
    fi
}

COMMITEOF

        # Insert the function before "# Check if we can make another call"
        awk '
        /^# Check if we can make another call$/ {
            while ((getline line < "/tmp/claude/ralph_commit_patch.txt") > 0) {
                print line
            }
            close("/tmp/claude/ralph_commit_patch.txt")
        }
        { print }
        ' "$RALPH_HOME/ralph_loop.sh" > "$RALPH_HOME/ralph_loop.sh.tmp"

        mv "$RALPH_HOME/ralph_loop.sh.tmp" "$RALPH_HOME/ralph_loop.sh"
        chmod +x "$RALPH_HOME/ralph_loop.sh"
        rm -f /tmp/claude/ralph_commit_patch.txt

        vecho "commit_changes function added"
    else
        vecho "commit_changes function already exists"
    fi
fi

# =============================================================================
# Patch 5: Add call to commit_changes after successful Claude Code execution
# =============================================================================
if [ -f "$RALPH_HOME/ralph_loop.sh" ]; then
    # Check if already patched (look for the commit_changes call)
    if ! grep -q 'commit_changes "\$loop_count"' "$RALPH_HOME/ralph_loop.sh"; then
        vecho "Adding commit_changes call after successful execution..."

        # Find the line with "log_status \"SUCCESS\" \"🎯 Loop" and add commit_changes after it
        sed -i.bak '/log_status "SUCCESS" "🎯 Loop #$loop_count completed\./a\
\
            # Auto-commit changes after successful execution\
            commit_changes "$loop_count"
' "$RALPH_HOME/ralph_loop.sh"

        rm -f "$RALPH_HOME/ralph_loop.sh.bak"
        chmod +x "$RALPH_HOME/ralph_loop.sh"

        vecho "commit_changes call added"
    else
        vecho "commit_changes call already exists"
    fi
fi

vecho "Ralph patches applied!"
