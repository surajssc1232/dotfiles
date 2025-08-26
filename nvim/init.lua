require('lspconfig') -- Leader Key and General Settings
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.fillchars:append { eob = " " }
vim.opt.cursorline = true
vim.opt.laststatus = 0
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.clipboard = "unnamedplus"
vim.opt.wrap = true
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
	use {
		"voltycodes/areyoulockedin.nvim",
		requires = { "nvim-lua/plenary.nvim" },
		config = function()
			require("areyoulockedin").setup({
				session_key = "06d82624-2d76-4cef-a278-3c2a2073130c",
			})
		end,
		event = "VimEnter",
	}
	use "wbthomason/packer.nvim"
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
local servers = { "lua_ls", "pyright", "ts_ls", "clangd" }
for _, server in ipairs(servers) do
	lspconfig[server].setup({
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

-- JDTLS Configuration
local function setup_jdtls()
	local jdtls = require('jdtls')

	-- Find the Mason installation path for jdtls using a more robust method
	local mason_path = vim.fn.stdpath('data') .. '/mason'
	local jdtls_path = mason_path .. '/packages/jdtls'

	-- Check if JDTLS is installed
	if vim.fn.isdirectory(jdtls_path) == 0 then
		vim.notify("JDTLS not found. Please run :MasonInstall jdtls", vim.log.levels.ERROR)
		return
	end

	-- Determine OS-specific config
	local config_dir
	if vim.fn.has('mac') == 1 then
		config_dir = jdtls_path .. '/config_mac'
	elseif vim.fn.has('unix') == 1 then
		config_dir = jdtls_path .. '/config_linux'
	else
		config_dir = jdtls_path .. '/config_win'
	end

	-- Find the launcher JAR
	local launcher_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')
	if launcher_jar == '' then
		vim.notify("JDTLS launcher jar not found", vim.log.levels.ERROR)
		return
	end

	-- Workspace directory (project-specific)
	local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
	local workspace_dir = vim.fn.stdpath('data') .. '/workspace/' .. project_name

	local config = {
		cmd = {
			'java',
			'-Declipse.application=org.eclipse.jdt.ls.core.id1',
			'-Dosgi.bundles.defaultStartLevel=4',
			'-Declipse.product=org.eclipse.jdt.ls.core.product',
			'-Dlog.protocol=true',
			'-Dlog.level=ALL',
			'-Xmx1g',
			'--add-modules=ALL-SYSTEM',
			'--add-opens', 'java.base/java.util=ALL-UNNAMED',
			'--add-opens', 'java.base/java.lang=ALL-UNNAMED',
			'-jar', launcher_jar,
			'-configuration', config_dir,
			'-data', workspace_dir,
		},

		root_dir = require('jdtls.setup').find_root({ '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }),

		settings = {
			java = {
				eclipse = {
					downloadSources = true,
				},
				configuration = {
					updateBuildConfiguration = "interactive",
				},
				maven = {
					downloadSources = true,
				},
				implementationsCodeLens = {
					enabled = true,
				},
				referencesCodeLens = {
					enabled = true,
				},
				references = {
					includeDecompiledSources = true,
				},
			}
		},

		init_options = {
			bundles = {}
		},

		on_attach = function(client, bufnr)
			on_attach(client, bufnr)

			-- JDTLS-specific keymaps
			local opts = { noremap = true, silent = true, buffer = bufnr }
			vim.keymap.set('n', '<leader>jo', jdtls.organize_imports, opts)
			vim.keymap.set('n', '<leader>jv', jdtls.extract_variable, opts)
			vim.keymap.set('n', '<leader>jc', jdtls.extract_constant, opts)
			vim.keymap.set('v', '<leader>jm', [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]], opts)
		end,

		capabilities = capabilities,
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
	size = 20,
	dir = "current",
	float_opts = {
		winblend = 10,
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

-- Autocompletion Setup
local cmp = require("cmp")
local lspkind = require("lspkind")

cmp.setup({
	snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "buffer" },
		{ name = "path" },
		{ name = "cmdline" },
	}),
	formatting = { format = lspkind.cmp_format({ mode = "symbol_text", maxwidth = 50, ellipsis_char = "...", with_text = true }) },
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
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

vim.api.nvim_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", { noremap = true, silent = true })

-- Colorscheme
vim.cmd([[colorscheme moonfly]])
