-- Personal Hyprland bindings for Omarchy Quattro.
-- These replace the old ~/.config/hypr/bindings.conf settings.

local bindings = {
  { "SUPER + RETURN", "Terminal", "uwsm-app -- xdg-terminal-exec --dir=\"$(omarchy-cmd-terminal-cwd)\"" },
  { "SUPER + SHIFT + F", "File manager", "uwsm-app -- nautilus --new-window" },
  { "SUPER + SHIFT + B", "Browser", "omarchy-launch-browser" },
  { "SUPER + SHIFT + ALT + B", "Browser (private)", "omarchy-launch-browser --private" },
  { "SUPER + SHIFT + M", "Music", "omarchy-launch-or-focus spotify" },
  { "SUPER + SHIFT + ALT + M", "Music TUI", "omarchy-launch-or-focus-tui cliamp" },
  { "SUPER + SHIFT + N", "Editor", "omarchy-launch-editor" },
  { "SUPER + SHIFT + D", "Docker", "omarchy-launch-tui lazydocker" },
  { "SUPER + SHIFT + G", "Signal", "omarchy-launch-or-focus ^signal$ \"uwsm-app -- signal-desktop\"" },
  { "SUPER + SHIFT + O", "Obsidian", "omarchy-launch-or-focus ^obsidian$ \"uwsm-app -- obsidian -disable-gpu --enable-wayland-ime\"" },
  { "SUPER + SHIFT + W", "Typora", "uwsm-app -- typora --enable-wayland-ime" },
  { "SUPER + SHIFT + SLASH", "Passwords", "uwsm-app -- 1password" },

  { "SUPER + SHIFT + A", "ChatGPT", "omarchy-launch-webapp \"https://chatgpt.com\"" },
  { "SUPER + SHIFT + ALT + A", "Grok", "omarchy-launch-webapp \"https://grok.com\"" },
  { "SUPER + SHIFT + C", "Calendar", "omarchy-launch-webapp \"https://app.hey.com/calendar/weeks/\"" },
  { "SUPER + SHIFT + E", "Email", "omarchy-launch-webapp \"https://app.hey.com\"" },
  { "SUPER + SHIFT + Y", "YouTube", "omarchy-launch-webapp \"https://youtube.com/\"" },
  { "SUPER + SHIFT + ALT + G", "WhatsApp", "omarchy-launch-or-focus-webapp WhatsApp \"https://web.whatsapp.com/\"" },
  { "SUPER + SHIFT + CTRL + G", "Google Messages", "omarchy-launch-or-focus-webapp \"Google Messages\" \"https://messages.google.com/web/conversations\"" },
  { "SUPER + SHIFT + P", "Google Photos", "omarchy-launch-or-focus-webapp \"Google Photos\" \"https://photos.google.com/\"" },
  { "SUPER + SHIFT + X", "X", "omarchy-launch-webapp \"https://x.com/\"" },
  { "SUPER + SHIFT + ALT + X", "X Post", "omarchy-launch-webapp \"https://x.com/compose/post\"" },
}

for _, binding in ipairs(bindings) do
  o.bind(binding[1], binding[2], binding[3])
end

-- Super+Shift+4 is the personal active-window screenshot shortcut.
hl.unbind("SUPER + SHIFT + 4")
o.bind("SUPER + SHIFT + 4", "Screenshot active window to clipboard", "omarchy-screenshot-active-window-clipboard")
