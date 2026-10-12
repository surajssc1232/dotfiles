-- Colorscheme generated from the quickshell theme. The palette lives in
-- ~/.local/state/quickshell/palette.json and is rewritten by apply-theme.sh.
vim.cmd("highlight clear")
vim.g.colors_name = "quickshell"

local path = vim.fn.expand("~/.local/state/quickshell/palette.json")
local ok, p = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
if not ok then
	p = { bg = "#282828", bgAlt = "#3c3836", border = "#504945", fg = "#ebdbb2", dim = "#928374",
		accent = "#fe8019", green = "#b8bb26", yellow = "#fabd2f", red = "#fb4934", blue = "#83a598" }
end

local function hl(name, v) vim.api.nvim_set_hl(0, name, v) end
local groups = {
	Normal = { fg = p.fg, bg = p.bg }, NormalNC = { fg = p.fg, bg = p.bg },
	NormalFloat = { fg = p.fg, bg = p.bg }, FloatBorder = { fg = p.border, bg = p.bg },
	Cursor = { fg = p.bg, bg = p.fg }, CursorLine = { bg = p.bgAlt }, CursorLineNr = { fg = p.accent, bold = true },
	LineNr = { fg = p.dim }, SignColumn = { bg = p.bg }, ColorColumn = { bg = p.bgAlt },
	Visual = { bg = p.border }, Search = { fg = p.bg, bg = p.yellow }, IncSearch = { fg = p.bg, bg = p.accent },
	MatchParen = { fg = p.accent, bold = true }, VertSplit = { fg = p.border }, WinSeparator = { fg = p.border },
	StatusLine = { fg = p.fg, bg = p.bgAlt }, StatusLineNC = { fg = p.dim, bg = p.bgAlt },
	Pmenu = { fg = p.fg, bg = p.bgAlt }, PmenuSel = { fg = p.bg, bg = p.accent },
	Folded = { fg = p.dim, bg = p.bgAlt }, NonText = { fg = p.border }, EndOfBuffer = { fg = p.bg },
	Comment = { fg = p.dim, italic = true }, Constant = { fg = p.accent }, String = { fg = p.green },
	Character = { fg = p.green }, Number = { fg = p.accent }, Boolean = { fg = p.accent },
	Identifier = { fg = p.blue }, Function = { fg = p.yellow }, Statement = { fg = p.red },
	Keyword = { fg = p.red }, Operator = { fg = p.fg }, PreProc = { fg = p.accent },
	Type = { fg = p.yellow }, Special = { fg = p.accent }, Delimiter = { fg = p.fg },
	Error = { fg = p.red, bold = true }, Todo = { fg = p.bg, bg = p.yellow, bold = true },
	DiagnosticError = { fg = p.red }, DiagnosticWarn = { fg = p.yellow },
	DiagnosticInfo = { fg = p.blue }, DiagnosticHint = { fg = p.green },
	DiffAdd = { bg = p.bgAlt, fg = p.green }, DiffChange = { bg = p.bgAlt, fg = p.yellow },
	DiffDelete = { bg = p.bgAlt, fg = p.red }, DiffText = { bg = p.border, fg = p.fg },
	Added = { fg = p.green }, Changed = { fg = p.yellow }, Removed = { fg = p.red },
	["@variable"] = { fg = p.fg }, ["@property"] = { fg = p.blue }, ["@parameter"] = { fg = p.blue },
	["@function"] = { link = "Function" }, ["@keyword"] = { link = "Keyword" },
	["@string"] = { link = "String" }, ["@type"] = { link = "Type" }, ["@comment"] = { link = "Comment" },
}
for name, v in pairs(groups) do hl(name, v) end
-- Glass: let the terminal's translucent background show through.
if p.glass then
	for _, g in ipairs({ "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "LineNr", "CursorLineNr", "FoldColumn" }) do
		local cur = vim.api.nvim_get_hl(0, { name = g, link = false })
		cur.bg = nil
		cur.ctermbg = nil
		vim.api.nvim_set_hl(0, g, cur)
	end
end
vim.g.quickshell_bg = p.bg
vim.o.background = (tonumber(p.bg:sub(2, 3), 16) > 127) and "light" or "dark"
