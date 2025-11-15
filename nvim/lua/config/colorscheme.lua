-- Colorscheme and highlight configuration

-- Set colorscheme
vim.cmd([[colorscheme gruvbox]])

-- Custom Pmenu highlights with your bg color (#282828)
vim.api.nvim_set_hl(0, 'Pmenu', { bg = '#282828', fg = '#ebdbb2' })
vim.api.nvim_set_hl(0, 'PmenuSel', { bg = '#3c3836', fg = '#fabd2f' })
vim.api.nvim_set_hl(0, 'PmenuSbar', { bg = '#282828' })
vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = '#504945' })

-- Custom Diagnostic highlights with your bg color (#282828)
vim.api.nvim_set_hl(0, 'DiagnosticFloat', { bg = '#282828', fg = '#ebdbb2' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', { bg = '#282828', fg = '#fb4934' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', { bg = '#282828', fg = '#fabd2f' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { bg = '#282828', fg = '#83a598' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', { bg = '#282828', fg = '#b8bb26' })

-- Underline overrides (for completeness, even if disabled)
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { undercurl = false, underline = false })

-- Float window highlights
vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#504945', bg = '#282828' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = '#282828', fg = '#ebdbb2' })