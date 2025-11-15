-- Diagnostics configuration
local log_file = vim.fn.tempname()

-- Error Logging Setup
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function()
		local diagnostics = vim.diagnostic.get(0)
		if #diagnostics > 0 then
			local file = io.open(log_file, "a")
			if file then
				for _, diag in ipairs(diagnostics) do
					file:write(string.format("[%s] %s: %s\n", os.date(), diag.source or "unknown", diag.message))
				end
				file:close()
			end
		end
	end,
})

vim.api.nvim_create_user_command("ViewLog", function()
	vim.cmd("edit " .. log_file)
end, { desc = "Open the error log file" })

-- Diagnostic configuration
vim.diagnostic.config({
	float = {
		focusable = false,
		style = "minimal",
		border = "single",
		source = false,
		header = "",
		prefix = "",
		winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,Search:None',
	},
	signs = false,
	underline = false,
	virtual_text = false,
	virtual_lines = {
		only_current_line = false,
		highlight_whole_line = true,
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(diag)
			local icons = {
				[vim.diagnostic.severity.WARN] = '',
			}
			local icon = icons[diag.severity] or ''
			local msg = diag.message:gsub('^%s*(.-)%s*$', '%1'):gsub('^%w+:%s*', '')
			return string.format('%s%s', icon, msg)
		end,
	},
	severity_sort = false,
})

-- LSP hover handler
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
	vim.lsp.handlers.hover,
	{ border = "rounded" }
)