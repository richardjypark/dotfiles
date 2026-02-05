# Shell startup time profiling
# Enable with: export ZSH_PROFILE_STARTUP=1
# View results: zsh_profile_report

# Only profile if explicitly enabled
if [[ -n "$ZSH_PROFILE_STARTUP" ]]; then
    # Profiling already initialized in zshenv, add final checkpoint
    if [[ -n "$_zsh_profile_start" ]] && typeset -f _zsh_profile_checkpoint >/dev/null; then
        _zsh_profile_checkpoint "shell configs loaded"
    fi
fi

# Display profiling report
zsh_profile_report() {
    if [[ -z "$_zsh_profile_times" ]]; then
        echo "No profiling data available."
        echo "To enable profiling, run:"
        echo "  export ZSH_PROFILE_STARTUP=1"
        echo "  exec zsh"
        return 1
    fi

    echo "=== Shell Startup Time Profile ==="
    echo ""

    local total_ms=$(( (_zsh_profile_end - _zsh_profile_start) ))
    printf "Total startup time: %d ms\n\n" "$total_ms"

    echo "Checkpoints:"
    echo "------------"

    local prev_time=$_zsh_profile_start
    local i=0
    for entry in "${_zsh_profile_times[@]}"; do
        local name="${entry%%:*}"
        local time="${entry##*:}"
        local delta=$(( time - prev_time ))
        printf "  %-30s +%4d ms  (at %4d ms)\n" "$name" "$delta" "$(( time - _zsh_profile_start ))"
        prev_time=$time
        ((i++))
    done

    echo ""
    echo "Slowest sections:"
    echo "-----------------"

    # Calculate deltas and sort
    local -a deltas
    prev_time=$_zsh_profile_start
    for entry in "${_zsh_profile_times[@]}"; do
        local name="${entry%%:*}"
        local time="${entry##*:}"
        local delta=$(( time - prev_time ))
        deltas+=("$delta:$name")
        prev_time=$time
    done

    # Sort and show top 5
    printf '%s\n' "${deltas[@]}" | sort -t: -k1 -nr | head -5 | while IFS=: read -r delta name; do
        printf "  %-30s %4d ms\n" "$name" "$delta"
    done
}

# Millisecond timer (gdate on macOS, GNU date on Linux, python3 fallback)
# macOS built-in date outputs literal %3N, so validate output is numeric
_profile_get_ms() { local t; t=$(gdate +%s%3N 2>/dev/null) || t=$(date +%s%3N 2>/dev/null); [[ "$t" =~ ^[0-9]+$ ]] && echo "$t" || python3 -c 'import time; print(int(time.time()*1000))'; }

# Quick startup time check (no profiling needed)
zsh_startup_time() {
    local start_time end_time

    echo "Measuring shell startup time (5 runs)..."
    echo ""

    local total=0
    local runs=5

    for i in $(seq 1 $runs); do
        # Time a new shell startup
        start_time=$(_profile_get_ms)
        zsh -ic 'exit' 2>/dev/null
        end_time=$(_profile_get_ms)

        local delta=$(( end_time - start_time ))
        total=$(( total + delta ))
        printf "  Run %d: %d ms\n" "$i" "$delta"
    done

    local avg=$(( total / runs ))
    echo ""
    printf "Average: %d ms\n" "$avg"

    if (( avg < 200 )); then
        echo "Status: Excellent (< 200ms)"
    elif (( avg < 500 )); then
        echo "Status: Good (< 500ms)"
    elif (( avg < 1000 )); then
        echo "Status: Acceptable (< 1s)"
    else
        echo "Status: Slow (> 1s) - consider optimizing"
    fi
}

# Profile a specific command/source
zsh_profile_source() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local start_time end_time
    start_time=$(_profile_get_ms)
    source "$file"
    end_time=$(_profile_get_ms)

    printf "Sourced %s in %d ms\n" "$file" "$(( end_time - start_time ))"
}
