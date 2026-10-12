-- Colorscheme, plus highlight overrides that make floats and the completion
-- popup follow whatever theme is active.

vim.cmd.colorscheme("quickshell")

vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	callback = function()
		local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
		local fg = normal.fg
		-- Transparent and base16 themes leave Normal without a background.
		local bg = normal.bg or (vim.g.quickshell_bg and tonumber(vim.g.quickshell_bg:sub(2), 16)) or 0x1d2021
		local sel = vim.api.nvim_get_hl(0, { name = "Visual" }).bg or 0x3c3836

		local border = vim.g.quickshell_border and tonumber(vim.g.quickshell_border:sub(2), 16) or fg
		-- The theme's border grey disappears against a wallpaper, so glass
		-- outlines take the accent instead.
		if vim.g.quickshell_glass and vim.g.quickshell_accent then
			border = tonumber(vim.g.quickshell_accent:sub(2), 16)
		end
		-- In glass mode floats take no background of their own, so the
		-- terminal's translucency shows through them like the editor itself.
		local float = vim.g.quickshell_glass and "NONE" or bg

		vim.api.nvim_set_hl(0, "NormalFloat", { bg = float, fg = fg })
		vim.api.nvim_set_hl(0, "FloatBorder", { bg = float, fg = border })
		vim.api.nvim_set_hl(0, "Pmenu", { bg = float, fg = fg })
		vim.api.nvim_set_hl(0, "PmenuSel", { bg = sel })
		vim.api.nvim_set_hl(0, "PmenuSbar", { bg = float })
		vim.api.nvim_set_hl(0, "PmenuThumb", { bg = sel })
	end,
})

-- The autocmd above is registered after the colorscheme is set, so fire it once.
vim.schedule(function()
	vim.cmd("doautocmd ColorScheme")
end)
