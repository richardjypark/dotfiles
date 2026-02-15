return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts = opts or {}
      opts.indent = opts.indent or {}

      -- Keep TS indent generally enabled, but avoid known hard-tab edge cases.
      opts.indent.enable = true
      opts.indent.disable = opts.indent.disable or {}
      local disable = {
        "go",
        "gomod",
        "gowork",
        "gotmpl",
        "make",
      }
      for _, lang in ipairs(disable) do
        if not vim.tbl_contains(opts.indent.disable, lang) then
          table.insert(opts.indent.disable, lang)
        end
      end

      return opts
    end,
  },
}
