vim.g.mapleader = " "
vim.opt.number = true
vim.opt.fillchars:append { eob = " " }
vim.opt.cursorline = true
vim.opt.laststatus = 0
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 200

vim.g.python3_host_prog = '/home/suraj/demo/venv/bin/python3.13'

-- Error Logging Setup
local log_file = vim.fn.tempname() -- Create a temporary file for logging
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function()
		local diagnostics = vim.diagnostic.get(0) -- Get diagnostics for current buffer
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

-- Command to view the log file
vim.api.nvim_create_user_command("ViewLog", function()
	vim.cmd("edit " .. log_file)
end, { desc = "Open the error log file" })

-- Diagnostics Configuration (hover on cursor hold)
vim.diagnostic.config({
	float = {
		focusable = false,
		style = "minimal",
		border = "rounded",
		source = "false",
		header = "",
		prefix = "",
	},
	signs = false,
})

vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		local float_opts = {
			focusable = false,
			close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
			border = "rounded",
			source = false,
			prefix = "",
			scope = "cursor",
		}
		vim.diagnostic.open_float(nil, float_opts)
	end,
})

-- Plugin Management with Packer
require("packer").startup(function(use)
	use "wbthomason/packer.nvim"
	use "xiyaowong/transparent.nvim"
	use 'Julian/lean.nvim'
	use { 'srcery-colors/srcery-vim', as = 'srcery' }
	use "WTFox/jellybeans.nvim"
	use "RRethy/base16-nvim"
	use "blazkowolf/gruber-darker.nvim"
	use({
		"neanias/everforest-nvim",
		-- Optional; default configuration will be used if setup isn't called.
		config = function()
			require("everforest").setup()
		end,
	})
	use { "akinsho/toggleterm.nvim", tag = '*', config = function()
		require("toggleterm").setup()
	end }
	use "ellisonleao/gruvbox.nvim"
	use "lukas-reineke/lsp-format.nvim"
	use {
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup({
				check_ts = true,
				enable_check_bracket_line = true,
				ignored_next_chars = "[%w%.]",
				map_cr = true,
				map_bs = true,
			})
		end,
	}
	use "nvim-tree/nvim-tree.lua"
	use {
		"nvim-telescope/telescope.nvim",
		requires = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup({
				defaults = {
					mappings = {
						i = {
							["<C-j>"] = require("telescope.actions").move_selection_next,
							["<C-k>"] = require("telescope.actions").move_selection_previous,
						},
					},
				},
			})
		end,
	}
	use {
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "lua", "python", "javascript", "c", "elixir", "eex", "heex", "java" },
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	}
	use "bluz71/vim-moonfly-colors"
	use "nvim-lua/plenary.nvim"
	use "neovim/nvim-lspconfig"
	use "williamboman/mason.nvim"
	use "williamboman/mason-lspconfig.nvim"
	use "hrsh7th/nvim-cmp"
	use "hrsh7th/cmp-buffer"
	use "hrsh7th/cmp-path"
	use "hrsh7th/cmp-nvim-lsp"
	use "onsails/lspkind.nvim"
	use "L3MON4D3/LuaSnip"
	use "lukas-reineke/indent-blankline.nvim"
	use "kyazdani42/nvim-web-devicons"
	use 'mfussenegger/nvim-jdtls'
end)

-- Indent Blankline Configuration
require("ibl").setup({
	indent = { char = "┋" },
	scope = { show_start = false, show_end = false },
})

-- Mason and LSP Configuration
require("mason").setup()
require("mason-lspconfig").setup({
	automatic_installation = true,
	ensure_installed = { "jdtls", "lua_ls", "pyright", "ts_ls", "clangd" },
})

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local on_attach = function(client, bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
end

-- Configure regular language servers (excluding jdtls)
local servers = { "lua_ls", "ts_ls", "clangd" }
for _, server in ipairs(servers) do
	lspconfig[server].setup({
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

local function setup_jdtls()
	local jdtls = require('jdtls')
	local config = {
		cmd = { 'jdtls' },
		root_dir = vim.fs.dirname(vim.fs.find({ '.git', 'mvnw', 'gradlew' }, { upward = true })[1]),
	}
	jdtls.start_or_attach(config)
end

-- Auto-command to setup JDTLS when opening Java files
vim.api.nvim_create_autocmd('FileType', {
	pattern = 'java',
	callback = setup_jdtls,
})

require('toggleterm').setup({
	open_mapping = "<C-\\>",
	direction = "float",
	size = 10,
	dir = "current",
	float_opts = {
		winblend = 20,
	},
})

--auto format Plugin
require("lsp-format").setup {}

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
		require("lsp-format").on_attach(client, args.buf)
	end,
})


local cmp = require("cmp")
local lspkind = require("lspkind")

cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},

	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),

		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			else
				fallback()
			end
		end, { "i", "s" }),

		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			else
				fallback()
			end
		end, { "i", "s" }),

		["<CR>"] = cmp.mapping.confirm({ select = true }),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "buffer" },
		{ name = "path" },
		{ name = "cmdline" },
	}),

	formatting = {
		format = lspkind.cmp_format({
			mode = "symbol_text",
			maxwidth = 50,
			ellipsis_char = "...",
		}),
	},

	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},

	experimental = {
		ghost_text = false, -- shows the inline suggestion
	},

	completion = {
		completeopt = "menu,menuone,noinsert,noselect", -- <--- important
	},
})

-- This sets a border around hover docs
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
	vim.lsp.handlers.hover,
	{ border = "rounded" }
)

-- Nvim-Tree Configuration
require("nvim-tree").setup()
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- Telescope Keybindings
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>", { noremap = true, silent = true })

-- Keybindings
vim.keymap.set("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Quit Neovim" })
vim.keymap.set("n", "<leader>w", ":w<CR>", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set("v", "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set("n", "<leader>r", ":PackerSync<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<leader>c", vim.lsp.buf.code_action, { desc = "Code Action" })
vim.keymap.set("v", "<leader>c", vim.lsp.buf.code_action, { desc = "Code Action (Visual)" })

vim.api.nvim_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })
-- Colorscheme
vim.cmd([[colorscheme base16-rose-pine-moon]])
