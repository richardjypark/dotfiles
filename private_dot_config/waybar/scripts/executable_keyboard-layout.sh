#!/bin/bash
# Read layout from the keyboard Hyprland marks as "main: yes".
# This avoids mismatches when multiple keyboard devices have different variant ordering.
LAYOUT=$(
  hyprctl devices | awk '
    /^[[:space:]]*Keyboard at / {
      in_keyboard = 1
      keymap = ""
      main = "no"
      next
    }
    in_keyboard && /^[[:space:]]*active keymap:/ {
      sub(/^[[:space:]]*active keymap: /, "", $0)
      keymap = $0
      next
    }
    in_keyboard && /^[[:space:]]*main:/ {
      sub(/^[[:space:]]*main: /, "", $0)
      main = $0
      if (main == "yes") {
        print keymap
        exit
      }
      in_keyboard = 0
      next
    }
  '
)

# Fallback if no main keyboard was found.
if [ -z "$LAYOUT" ]; then
  LAYOUT=$(hyprctl devices | awk '/active keymap:/ {sub(/.*active keymap: /, "", $0); print; exit}')
fi

# Output simplified names
case "$LAYOUT" in
    "English (US)")
        echo "US"
        ;;
    "English (Dvorak)")
        echo "DV"
        ;;
    *)
        echo "$LAYOUT"
        ;;
esac
