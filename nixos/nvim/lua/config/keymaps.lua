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
map("v", "<leader>d", ":Rover<CR>", { silent = true, desc = "Ask Rover" })
