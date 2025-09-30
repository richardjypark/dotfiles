#!/bin/sh
set -e

# Quiet mode by default
VERBOSE=${VERBOSE:-false}
vecho() { 
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

# State tracking for chezmoi scripts
# This creates a simple state tracking system to avoid redundant work

STATE_DIR="$HOME/.cache/chezmoi-state"
mkdir -p "$STATE_DIR"

# Function to check if a setup step was completed
is_setup_complete() {
    [ -f "$STATE_DIR/$1.done" ]
}

# Function to mark a setup step as complete
mark_setup_complete() {
    touch "$STATE_DIR/$1.done"
}

# Function to clear a setup state (useful for forced re-runs)
clear_setup_state() {
    rm -f "$STATE_DIR/$1.done"
}

# Export environment variables for use in other scripts
export STATE_DIR

vecho "State tracking initialized in $STATE_DIR" 