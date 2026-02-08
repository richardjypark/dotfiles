#!/bin/bash
#
# today.sh - Fix commit timestamps that fall during work hours
#
# This script checks for commits made during weekday work hours (9am-5pm Mon-Fri in WORK_TZ),
# fixes their timestamps to appear after hours with natural randomization,
# and pushes to the dev branch.
#
# NOTE: This script scans ALL commits (including already-pushed/immutable ones)
# and uses --ignore-immutable to modify them. This will rewrite history and
# requires a force push to the remote.
#
# Usage:
#   ./scripts/dev/today.sh              # Check and fix
#   DRY_RUN=true ./scripts/dev/today.sh # Check only (no changes)
#
# Environment variables:
#   DRY_RUN          - Set to "true" to only report violations (default: false)
#   WORK_START_HOUR  - Start of work hours (default: 9)
#   WORK_END_HOUR    - End of work hours (default: 17)
#   WORK_TZ          - IANA timezone for "work hours" (default: America/New_York)
#   SKIP_PUSH        - Set to "true" to skip pushing to remote (default: false)
#

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

WORK_START_HOUR="${WORK_START_HOUR:-9}"
WORK_END_HOUR="${WORK_END_HOUR:-17}"
WORK_TZ="${WORK_TZ:-America/New_York}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_PUSH="${SKIP_PUSH:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  echo -e "${CYAN}[STEP]${NC} $1"
}

# ============================================================================
# Utility Functions
# ============================================================================

# python3 is required for robust timezone parsing/conversion.
if ! command -v python3 >/dev/null 2>&1; then
  log_error "python3 is required but was not found in PATH"
  exit 1
fi

# Convert timestamp to epoch seconds
timestamp_to_epoch() {
  local ts="$1"
  python3 - "$ts" <<'PY' 2>/dev/null || echo "0"
import datetime as dt
import re
import sys

s = sys.argv[1].strip()
m = re.match(r"^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})(\.\d+)?\s+([+-]\d{2}:\d{2})$", s)
if m:
    iso = f"{m.group(1)}T{m.group(2)}{m.group(3) or ''}{m.group(4)}"
else:
    iso = s

try:
    ts = int(dt.datetime.fromisoformat(iso).timestamp())
    print(ts)
except Exception:
    print("0")
PY
}

# Convert epoch to ISO timestamp
epoch_to_iso() {
  local epoch="$1"
  python3 - "$epoch" "$WORK_TZ" <<'PY'
import datetime as dt
import sys
from zoneinfo import ZoneInfo

epoch = int(sys.argv[1])
tz = ZoneInfo(sys.argv[2])
t = dt.datetime.fromtimestamp(epoch, tz)
offset = t.strftime("%z")
offset = f"{offset[:3]}:{offset[3:]}" if offset else "+00:00"
print(f"{t.strftime('%Y-%m-%dT%H:%M:%S')}{offset}")
PY
}

# Return localized day/hour/day-abbrev for a timestamp.
# Output format: day_of_week|hour|day_abbrev
get_local_time_parts() {
  local ts="$1"
  python3 - "$ts" "$WORK_TZ" <<'PY' 2>/dev/null || echo "0|0|???"
import datetime as dt
import re
import sys
from zoneinfo import ZoneInfo

s = sys.argv[1].strip()
tz = ZoneInfo(sys.argv[2])
m = re.match(r"^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})(\.\d+)?\s+([+-]\d{2}:\d{2})$", s)
if m:
    iso = f"{m.group(1)}T{m.group(2)}{m.group(3) or ''}{m.group(4)}"
else:
    iso = s

try:
    local = dt.datetime.fromisoformat(iso).astimezone(tz)
    print(f"{local.isoweekday()}|{local.hour}|{local.strftime('%a')}")
except Exception:
    print("0|0|???")
PY
}

# Check if timestamp is during configured work hours in WORK_TZ
is_work_hours() {
  local ts="$1"
  local parts day_of_week hour

  parts=$(get_local_time_parts "$ts")
  day_of_week="${parts%%|*}"
  hour="${parts#*|}"
  hour="${hour%%|*}"

  # Check: weekday (1-5) AND within work hours
  if [[ "$day_of_week" -ge 1 && "$day_of_week" -le 5 ]] && \
     [[ "$hour" -ge "$WORK_START_HOUR" && "$hour" -lt "$WORK_END_HOUR" ]]; then
    return 0  # true - is work hours
  fi
  return 1  # false - not work hours
}

# Generate random after-hours timestamp
generate_after_hours_timestamp() {
  local original_ts="$1"
  local min_epoch="$2"
  local base_epoch random_minutes new_epoch

  # Base: 5pm local time on the same local date as original commit.
  base_epoch=$(python3 - "$original_ts" "$WORK_TZ" <<'PY' 2>/dev/null || echo "0"
import datetime as dt
import re
import sys
from zoneinfo import ZoneInfo

s = sys.argv[1].strip()
tz = ZoneInfo(sys.argv[2])
m = re.match(r"^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})(\.\d+)?\s+([+-]\d{2}:\d{2})$", s)
if m:
    iso = f"{m.group(1)}T{m.group(2)}{m.group(3) or ''}{m.group(4)}"
else:
    iso = s

try:
    local = dt.datetime.fromisoformat(iso).astimezone(tz)
    base = local.replace(hour=17, minute=0, second=0, microsecond=0)
    print(int(base.timestamp()))
except Exception:
    print("0")
PY
)

  random_minutes=$((RANDOM % 180))
  new_epoch=$((base_epoch + random_minutes * 60))
  # Ensure we're after the minimum (parent timestamp + jitter)
  local jitter=$((RANDOM % 4 + 1))  # 1-4 minutes
  local min_required=$((min_epoch + jitter * 60))

  if [[ "$new_epoch" -le "$min_required" ]]; then
    new_epoch=$min_required
  fi

  epoch_to_iso "$new_epoch"
}

# ============================================================================
# Core Functions
# ============================================================================

# Find all commits during work hours
find_work_hour_commits() {
  while IFS='|' read -r change_id timestamp desc; do
    [[ -z "$timestamp" ]] && continue

    if is_work_hours "$timestamp"; then
      echo "$change_id|$timestamp|$desc"
    fi
  done < <(jj log --no-graph -T 'change_id.short() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "\n"' -r '::@ & ~root()' --ignore-working-copy 2>/dev/null)
}

# Check chronological order and find violations
find_chronological_violations() {
  local prev_epoch="" prev_ts=""

  while IFS='|' read -r change_id timestamp; do
    [[ -z "$timestamp" ]] && continue

    local epoch
    epoch=$(timestamp_to_epoch "$timestamp")

    if [[ -n "$prev_epoch" ]] && [[ "$epoch" -lt "$prev_epoch" ]]; then
      echo "$change_id|$timestamp|$prev_ts"
    fi

    prev_epoch="$epoch"
    prev_ts="$timestamp"
  done < <(jj log --no-graph --reversed -T 'change_id.short() ++ "|" ++ author.timestamp() ++ "\n"' -r '::@ & ~root()' --ignore-working-copy 2>/dev/null)
}

# Fix a single commit's timestamp (uses --ignore-immutable for pushed commits)
fix_commit_timestamp() {
  local change_id="$1"
  local new_timestamp="$2"

  local desc
  desc=$(jj log --no-graph -T 'description.first_line()' -r "$change_id" --ignore-working-copy 2>/dev/null)

  JJ_TIMESTAMP="$new_timestamp" jj describe "$change_id" -m "$desc" --reset-author --ignore-working-copy --ignore-immutable 2>&1 | grep -v "deprecated" || true
}

# Fix all work hour violations
fix_work_hour_violations() {
  local fixed_count=0
  local last_epoch=0

  # Process in topological order (oldest first)
  while IFS='|' read -r change_id timestamp desc; do
    [[ -z "$timestamp" ]] && continue

    if is_work_hours "$timestamp"; then
      log_step "Fixing: $change_id - $desc"

      local new_ts
      new_ts=$(generate_after_hours_timestamp "$timestamp" "$last_epoch")

      fix_commit_timestamp "$change_id" "$new_ts"

      last_epoch=$(timestamp_to_epoch "$new_ts")
      ((fixed_count++))
    else
      # Update last_epoch for non-violation commits too
      last_epoch=$(timestamp_to_epoch "$timestamp")
    fi
  done < <(jj log --no-graph --reversed -T 'change_id.short() ++ "|" ++ author.timestamp() ++ "|" ++ description.first_line() ++ "\n"' -r '::@ & ~root()' --ignore-working-copy 2>/dev/null)

  echo "$fixed_count"
}

# Fix chronological order violations iteratively
fix_chronological_order() {
  local iteration=0
  local max_iterations=20

  while [[ $iteration -lt $max_iterations ]]; do
    ((iteration++))

    # Find first violation
    local violation
    violation=$(jj log --no-graph --reversed -T 'change_id.short() ++ "|" ++ author.timestamp() ++ "\n"' -r '::@ & ~root()' --ignore-working-copy 2>/dev/null | {
      local prev_epoch="" prev_ts=""

      while IFS='|' read -r change_id timestamp; do
        [[ -z "$timestamp" ]] && continue

        local epoch
        epoch=$(timestamp_to_epoch "$timestamp")

        if [[ -n "$prev_epoch" ]] && [[ "$epoch" -lt "$prev_epoch" ]]; then
          echo "$change_id|$timestamp|$prev_ts"
          break
        fi

        prev_epoch="$epoch"
        prev_ts="$timestamp"
      done
    })

    if [[ -z "$violation" ]]; then
      return 0  # No more violations
    fi

    local child_id parent_ts
    child_id=$(echo "$violation" | cut -d'|' -f1)
    parent_ts=$(echo "$violation" | cut -d'|' -f3)

    # Calculate new timestamp: parent + 1-5 minutes
    local parent_epoch new_epoch jitter new_ts
    parent_epoch=$(timestamp_to_epoch "$parent_ts")
    jitter=$((RANDOM % 4 + 1))
    new_epoch=$((parent_epoch + jitter * 60))
    new_ts=$(epoch_to_iso "$new_epoch")

    log_step "Fixing chronological: $child_id → $new_ts"
    fix_commit_timestamp "$child_id" "$new_ts"
  done

  log_warn "Max iterations ($max_iterations) reached"
  return 1
}

# Push to remote
push_to_remote() {
  log_step "Pushing to remote..."

  if jj git push -b dev --ignore-working-copy 2>&1; then
    log_info "Successfully pushed to remote"
    return 0
  else
    log_error "Failed to push to remote"
    return 2
  fi
}

# ============================================================================
# Main
# ============================================================================

main() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║           Work Hours Timestamp Fixer                          ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  log_info "Work hours defined as: ${WORK_START_HOUR}:00 - ${WORK_END_HOUR}:00 (Mon-Fri, ${WORK_TZ})"
  [[ "$DRY_RUN" == "true" ]] && log_warn "DRY RUN MODE - No changes will be made"
  echo ""

  # Step 1: Find work hour violations
  log_step "Scanning for work hour violations..."

  local violations
  violations=$(find_work_hour_commits)
  local violation_count=0

  if [[ -n "$violations" ]]; then
    violation_count=$(echo "$violations" | wc -l | tr -d ' ')
  fi

  if [[ "$violation_count" -eq 0 ]]; then
    echo ""
    log_info "✅ No commits found during work hours"
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo "  Commits scanned: $(jj log --no-graph -T '"\n"' -r '::@ & ~root()' --ignore-working-copy 2>/dev/null | wc -l | xargs)"
    echo "  Violations found: 0"
    echo ""
    exit 0
  fi

  # Step 2: Display violations
  echo ""
  log_warn "Found $violation_count commit(s) during work hours:"
  echo ""

  while IFS='|' read -r change_id timestamp desc; do
    [[ -z "$timestamp" ]] && continue
    local parts day_name hour
    parts=$(get_local_time_parts "$timestamp")
    day_name="${parts##*|}"
    hour="${parts#*|}"
    hour="${hour%%|*}"

    echo -e "  ${YELLOW}$change_id${NC} | $timestamp (${day_name} ${hour}:xx ${WORK_TZ}) | ${desc:0:50}..."
  done <<< "$violations"

  echo ""

  # Step 3: Dry run exit
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN - Would fix $violation_count commit(s)"
    echo ""
    exit 0
  fi

  # Step 4: Fix work hour violations
  log_step "Fixing work hour violations..."
  local fixed_count
  fixed_count=$(fix_work_hour_violations)
  log_info "Fixed $fixed_count work hour violation(s)"

  # Step 5: Fix any chronological order issues
  log_step "Checking chronological order..."
  if ! fix_chronological_order; then
    log_error "Failed to fix all chronological order issues"
    exit 1
  fi
  log_info "Chronological order verified"

  # Step 6: Push to remote
  if [[ "$SKIP_PUSH" != "true" ]]; then
    if ! push_to_remote; then
      exit 2
    fi
  else
    log_warn "Skipping push (SKIP_PUSH=true)"
  fi

  # Step 7: Summary
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                        Summary                                ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${GREEN}✅${NC} Work hour violations fixed: $fixed_count"
  echo -e "  ${GREEN}✅${NC} Chronological order: verified"
  [[ "$SKIP_PUSH" != "true" ]] && echo -e "  ${GREEN}✅${NC} Pushed to remote: dev"
  echo ""

  # Final verification
  local remaining
  remaining=$(find_work_hour_commits | grep -c '|' || true)
  if [[ "$remaining" -gt 0 ]]; then
    log_warn "⚠️  $remaining violation(s) still remain - may need manual review"
    exit 1
  fi

  log_info "All done!"
  exit 0
}

# Run main
main "$@"
