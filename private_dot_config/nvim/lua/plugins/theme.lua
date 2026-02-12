local omarchy_theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")

-- Prefer Omarchy's live theme file when available; fall back to a safe built-in theme elsewhere.
if vim.fn.filereadable(omarchy_theme_file) == 1 then
  local ok, spec = pcall(dofile, omarchy_theme_file)
  if ok and type(spec) == "table" then
    return spec
  end
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "habamax",
    },
  },
}
