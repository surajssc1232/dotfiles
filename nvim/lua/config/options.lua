-- Editor options and diagnostic display.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.cursorline = false
vim.opt.fillchars:append({ eob = " " })

-- Indentation mirrors Helix: 2 spaces by default, with per-language
-- overrides from Helix's built-ins and ~/.config/helix/languages.toml.
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2

local indent_by_ft = {
	rust = 4,
	python = 4,
	java = 4,
	fish = 4,
	zig = 4,
	c = 4,
	cpp = 4,
	odin = 4,
}
vim.api.nvim_create_autocmd("FileType", {
	pattern = vim.tbl_keys(indent_by_ft),
	callback = function(args)
		local width = indent_by_ft[args.match]
		vim.bo[args.buf].expandtab = true
		vim.bo[args.buf].shiftwidth = width
		vim.bo[args.buf].softtabstop = width
		vim.bo[args.buf].tabstop = width
	end,
})
-- Go uses real tabs, 4 wide.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function(args)
		vim.bo[args.buf].expandtab = false
		vim.bo[args.buf].shiftwidth = 4
		vim.bo[args.buf].softtabstop = 0
		vim.bo[args.buf].tabstop = 4
	end,
})

vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 200
vim.opt.termguicolors = true
-- Rounded, to match niri's window corners. Box drawing has no heavy rounded
-- corners, so this is the thin line; glass mode colours it with the accent.
vim.opt.winborder = "rounded"

-- Completion popup sizing.
vim.opt.pumheight = 12
vim.opt.pumwidth = 45

-- Messages are drawn by config/diagnostics.lua, so the
-- built-in virtual text stays off.
vim.diagnostic.config({
	signs = false,
	underline = true,
	virtual_text = false,
	float = { border = "rounded", source = true },
})

-- Helix-style curly underline in the diagnostic colour. Re-applied on every
-- colorscheme change, since schemes reset these groups.
local function diagnostic_undercurl()
	for _, level in ipairs({ "Error", "Warn", "Info", "Hint" }) do
		local fg = vim.api.nvim_get_hl(0, { name = "Diagnostic" .. level, link = false }).fg
		vim.api.nvim_set_hl(0, "DiagnosticUnderline" .. level, { undercurl = true, sp = fg })
	end
end
diagnostic_undercurl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = diagnostic_undercurl })
