-- Keybindings

-- General keybindings
vim.keymap.set("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Quit Neovim" })
vim.keymap.set("n", "<leader>w", ":w<CR>", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set("v", "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set("n", "<leader>r", ":PackerSync<CR>", { noremap = true, silent = true })

-- LSP keybindings
vim.keymap.set("n", "<leader>c", vim.lsp.buf.code_action, { desc = "Code Action" })
vim.keymap.set("v", "<leader>c", vim.lsp.buf.code_action, { desc = "Code Action (Visual)" })
vim.api.nvim_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })

-- Plugin keybindings
-- Nvim-Tree
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- Telescope
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>", { noremap = true, silent = true })

-- Rover
vim.keymap.set("v", "<leader>d", ":Rover<CR>", { noremap = true, silent = true })