-- Colorscheme, plus highlight overrides that make floats and the completion
-- popup follow whatever theme is active.

vim.cmd.colorscheme("gruvbox-material")

vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
		local fg = normal.fg
		-- Transparent and base16 themes leave Normal without a background.
		local bg = normal.bg or 0x1d2021
		local sel = vim.api.nvim_get_hl(0, { name = "Visual" }).bg or 0x3c3836

		vim.api.nvim_set_hl(0, "NormalFloat", { bg = bg, fg = fg })
		vim.api.nvim_set_hl(0, "FloatBorder", { bg = bg, fg = fg })
		vim.api.nvim_set_hl(0, "Pmenu", { bg = "NONE", fg = fg })
		vim.api.nvim_set_hl(0, "PmenuSel", { bg = sel })
		vim.api.nvim_set_hl(0, "PmenuSbar", { bg = bg })
		vim.api.nvim_set_hl(0, "PmenuThumb", { bg = sel })
	end,
})

-- The autocmd above is registered after the colorscheme is set, so fire it once.
vim.schedule(function()
	vim.cmd("doautocmd ColorScheme")
end)
