-- Global keymaps. Anything LSP-specific is mapped per-buffer on attach,
-- over in lsp.lua.

local map = vim.keymap.set

map("n", "<leader>w", ":w<CR>", { silent = true, desc = "Write" })
map("n", "<leader>q", ":q<CR>", { silent = true, desc = "Quit" })
map("n", "<leader>r", ":PackerSync<CR>", { silent = true, desc = "Sync plugins" })

map("v", "<leader>y", '"+y', { silent = true, desc = "Yank to system clipboard" })
map("v", "<leader>p", '"+p', { silent = true, desc = "Paste from system clipboard" })

map("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "Toggle file tree" })
map("n", "<leader>ff", ":Telescope find_files<CR>", { silent = true, desc = "Find files" })
map("n", "<leader>fg", ":Telescope live_grep<CR>", { silent = true, desc = "Live grep" })
map("n", "<leader>k", vim.diagnostic.open_float, { silent = true, desc = "Show diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Prev diagnostic" })

-- Helix-style :format and :fmt. Command names have to start with a capital, so
-- these are abbreviations, and only expand when they are the whole command.
for _, name in ipairs({ "format", "fmt" }) do
	map("ca", name, function()
		local whole = vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == name
		return whole and "lua vim.lsp.buf.format()" or name
	end, { expr = true, desc = "Format buffer with LSP" })
end
