-- Minimal inline diagnostics: one message, for the line the cursor is on,
-- drawn after the code as a coloured dot and italic text. Every other
-- problem is still marked by its underline.
--
--   print(hi   ● Missed symbol `)`.

local ns = vim.api.nvim_create_namespace("inline_diagnostic")

local sev_hl = {
	[vim.diagnostic.severity.ERROR] = "Error",
	[vim.diagnostic.severity.WARN] = "Warn",
	[vim.diagnostic.severity.INFO] = "Info",
	[vim.diagnostic.severity.HINT] = "Hint",
}

-- Italic copies of the Diagnostic groups, rebuilt on every colorscheme change.
local function italic_groups()
	for _, level in pairs(sev_hl) do
		local fg = vim.api.nvim_get_hl(0, { name = "Diagnostic" .. level, link = false }).fg
		vim.api.nvim_set_hl(0, "DiagnosticMsg" .. level, { fg = fg, italic = true })
	end
end
italic_groups()
vim.api.nvim_create_autocmd("ColorScheme", { callback = italic_groups })

local function render()
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if vim.fn.mode():sub(1, 1) == "i" then return end

	local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
	-- Servers report one problem several times; the most severe one wins.
	local top
	for _, d in ipairs(vim.diagnostic.get(buf, { lnum = lnum })) do
		if not top or d.severity < top.severity or (d.severity == top.severity and d.col < top.col) then
			top = d
		end
	end
	if not top then return end

	local msg = vim.split(top.message, "\n", { plain = true, trimempty = true })[1] or ""
	local level = sev_hl[top.severity]
	vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
		virt_text = { { "  " }, { "● ", "Diagnostic" .. level }, { msg, "DiagnosticMsg" .. level } },
		virt_text_pos = "eol",
	})
end

vim.api.nvim_create_autocmd({ "DiagnosticChanged", "CursorMoved", "BufEnter", "InsertLeave" }, {
	callback = render,
})
