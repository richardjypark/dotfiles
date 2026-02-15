-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- Prevent Neovim's default snippet <Tab> mapping from intercepting insert mode.
local function force_literal_tab()
  pcall(vim.keymap.del, "i", "<Tab>")
  pcall(vim.keymap.del, "s", "<Tab>")
  vim.keymap.set("i", "<Tab>", "<Tab>", { noremap = true, silent = true })
  vim.keymap.set("s", "<Tab>", "<Tab>", { noremap = true, silent = true })
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = force_literal_tab,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  callback = force_literal_tab,
})
