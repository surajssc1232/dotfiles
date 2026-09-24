-- Editor options and diagnostic display.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.cursorline = false
vim.opt.fillchars:append({ eob = " " })
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 200
vim.opt.termguicolors = true
vim.opt.winborder = "rounded"

-- Completion popup sizing.
vim.opt.pumheight = 12
vim.opt.pumwidth = 45

vim.diagnostic.config({
	signs = false,
	underline = false,
	virtual_text = {
		prefix = "⏤",
		suffix = " ",
		spacing = 2,
	},
})
