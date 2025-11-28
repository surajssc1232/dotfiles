-- Colorscheme and highlight configuration

-- Set colorscheme
vim.cmd([[colorscheme gruvbox]])  -- change anytime

-- Add this at the very end of your colorscheme.lua
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
    local bg = normal_hl.bg
    local fg = normal_hl.fg
    
    -- For transparent/base16 themes, use a dark fallback
    if not bg then
      bg = 0x1d2021  -- or use "NONE" for full transparency
    end
    
    local sel = vim.api.nvim_get_hl(0, { name = "Visual" }).bg or 0x3c3836

    vim.api.nvim_set_hl(0, "NormalFloat", { bg = bg, fg = fg })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = fg, bg = bg })
    vim.api.nvim_set_hl(0, "Pmenu",        { bg = "NONE", fg = fg })  -- ← Force NONE
    vim.api.nvim_set_hl(0, "PmenuSel",     { bg = sel })
    vim.api.nvim_set_hl(0, "PmenuSbar",    { bg = bg })
    vim.api.nvim_set_hl(0, "PmenuThumb",   { bg = sel })
  end,
})

-- Apply immediately
vim.schedule(function() vim.cmd("doautocmd ColorScheme") end)
