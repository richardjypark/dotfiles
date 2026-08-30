-- Personal Hyprland input settings for Omarchy Quattro.
-- These replace the old ~/.config/hypr/input.conf settings.

hl.config({
  input = {
    -- Dvorak is the first layout. Alt + Shift switches to US.
    kb_layout = "us,us",
    kb_variant = "dvorak,",
    kb_options = "caps:escape,grp:alt_shift_toggle",

    repeat_rate = 40,
    repeat_delay = 600,
    numlock_by_default = true,

    touchpad = {
      scroll_factor = 0.4,
    },
  },
})

-- Keep the terminal scroll behavior from the previous configuration.
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
