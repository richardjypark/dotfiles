#!/bin/bash
# Keep all keyboards on the same layout index by following the main keyboard.

DEVICES="$(hyprctl devices)"

read -r CURRENT_INDEX TARGET_INDEX <<EOF
$(printf '%s\n' "$DEVICES" | awk '
  BEGIN { in_keyboard = 0; is_main = "no"; idx = ""; max_idx = 0 }
  /^[[:space:]]*Keyboard at / {
    in_keyboard = 1
    is_main = "no"
    idx = ""
    next
  }
  in_keyboard && /^[[:space:]]*active layout index:/ {
    sub(/^[[:space:]]*active layout index: /, "", $0)
    idx = $0 + 0
    next
  }
  in_keyboard && /^[[:space:]]*rules:/ {
    if (match($0, /l "[^"]*"/)) {
      layouts = substr($0, RSTART + 3, RLENGTH - 4)
      n = split(layouts, arr, /,/)
      if (n > 0) {
        max_idx = n - 1
      }
    }
    next
  }
  in_keyboard && /^[[:space:]]*main:/ {
    sub(/^[[:space:]]*main: /, "", $0)
    is_main = $0
    if (is_main == "yes" && idx != "") {
      target = (idx == max_idx ? 0 : idx + 1)
      print idx, target
      exit
    }
    in_keyboard = 0
  }
')
EOF

if [ -z "$TARGET_INDEX" ]; then
  exit 1
fi

# Get keyboard names and skip power/video pseudo-devices.
KEYBOARDS=$(printf '%s\n' "$DEVICES" | awk '
  /^[[:space:]]*Keyboard at / { want_name = 1; next }
  want_name == 1 {
    name = $0
    sub(/^[[:space:]]+/, "", name)
    if (name !~ /^power-button/ && name != "video-bus") {
      print name
    }
    want_name = 0
  }
')

while IFS= read -r keyboard; do
  [ -n "$keyboard" ] || continue
  hyprctl switchxkblayout "$keyboard" "$TARGET_INDEX" >/dev/null 2>&1
done <<< "$KEYBOARDS"
