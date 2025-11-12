vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true
vim.opt.fillchars:append { eob = " " }
vim.opt.cursorline = false
vim.opt.laststatus = 0
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 200
vim.opt.termguicolors = true
vim.opt.encoding = "utf-8"

vim.g.python3_host_prog = '/home/suraj/demo/venv/bin/python3.13'

-- Error Logging Setup
local log_file = vim.fn.tempname()
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

vim.diagnostic.config({
	float = { -- Unchanged: Shows warnings/errors on hover
		focusable = false,
		style = "minimal",
		border = "single",
		source = false,
		header = "",
		prefix = "",
		winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,Search:None',
	},
	signs = false,
	underline = false,   -- Underlines for warnings (and errors)
	virtual_text = false, -- Off to avoid clutter
	virtual_lines = {    -- Now for errors + warnings as wrapped lines (always-on)
		only_current_line = false,
		highlight_whole_line = true,
		severity = { min = vim.diagnostic.severity.HINT }, -- Changed: Includes WARN+ (warnings & errors)
		format = function(diag)
			local icons = {
				[vim.diagnostic.severity.WARN] = '',
			} -- Icons for both severities
			local icon = icons[diag.severity] or ''
			local msg = diag.message:gsub('^%s*(.-)%s*$', '%1'):gsub('^%w+:%s*', '')
			return string.format('%s%s', icon, msg)
		end,
	},
	severity_sort = false, -- Sorts errors above warnings
})


-- Auto-show diagnostic float on hover (for warnings/errors; delays to avoid flicker)
-- vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
-- 	callback = function()
-- 		local opts = {
-- 			focusable = false,
-- 			border = "rounded",
-- 			source = "if_many",
-- 			scope = "cursor", -- Or "line" for all on the line
-- 		}
-- 		vim.diagnostic.open_float(opts)
-- 	end,
-- 	desc = "Show diagnostic float on hover",
-- })

-- Plugin Management with Packer
require("packer").startup(function(use)
	use "wbthomason/packer.nvim"
	-- Example with lazy.nvim
	use "xiyaowong/transparent.nvim"
	use 'Julian/lean.nvim'
	use "surajssc1232/rover.nvim"
	use { 'srcery-colors/srcery-vim', as = 'srcery' }
	use "WTFox/jellybeans.nvim"
	use "RRethy/base16-nvim"
	use "blazkowolf/gruber-darker.nvim"
	use({
		"neanias/everforest-nvim",
		config = function()
			require("everforest").setup()
		end,
	})
	use { "akinsho/toggleterm.nvim", tag = '*', config = function()
		require("toggleterm").setup()
	end }
	use { "ellisonleao/gruvbox.nvim" }
	use "sainnhe/gruvbox-material"
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
				ensure_installed = { "lua", "python", "javascript", "c", "elixir", "eex", "heex", "java", "rust", "zig" },
				highlight = { enable = true },
				indent = { enable = true },
			})
		end,
	}
	use "bluz71/vim-moonfly-colors"
	use "nvim-lua/plenary.nvim"
	use "neovim/nvim-lspconfig"
	use "hrsh7th/nvim-cmp"
	use "hrsh7th/cmp-buffer"
	use "hrsh7th/cmp-path"
	use "hrsh7th/cmp-nvim-lsp"
	use "L3MON4D3/LuaSnip"
	use "lukas-reineke/indent-blankline.nvim"
	use "kyazdani42/nvim-web-devicons"
	use 'mfussenegger/nvim-jdtls'
	use 'echasnovski/mini.icons'
end)


-- Mini.icons setup
require('mini.icons').setup()

-- Indent Blankline Configuration
require("ibl").setup({
	indent = { char = "┋" },
	scope = { show_start = false, show_end = false },
})

require('rover').setup({
	api_key = "AIzaSyC27VXi-WRBetfH3lZCMmGTIzbnxBPRzPQ",
	window_width = 150,
	window_height = 25,
	model = 'gemini-2.5-flash'
})

-- LSP Configuration
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local lsp_attached_buffers = {}

local on_attach = function(client, bufnr)
	local buffer_key = bufnr .. "_" .. client.name
	if lsp_attached_buffers[buffer_key] then
		return
	end
	lsp_attached_buffers[buffer_key] = true

	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

	require("lsp-format").on_attach(client, bufnr)
end

-- Configure LSP servers using vim.lsp.config (Neovim 0.11+ syntax)
vim.lsp.config['lua_ls'] = {
	cmd = { 'lua-language-server' },
	filetypes = { 'lua' },
	root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
	capabilities = capabilities,
	settings = {
		Lua = {
			diagnostics = {
				globals = { 'vim' }
			}
		}
	}
}

vim.lsp.config['fish-lsp'] = {
	cmd = { 'fish-lsp', 'start' },
	filetypes = { 'fish' },
	capabilities = capabilities,
}

vim.lsp.config['perlls'] = {
	cmd = { 'nix-shell', '--run', 'perl -MPerl::LanguageServer -e "Perl::LanguageServer::run"' },
	filetypes = { 'perl' },
	root_markers = { '.git', 'Makefile.PL', 'Build.PL', 'shell.nix' },
	capabilities = capabilities,
}


vim.lsp.config['qmlls'] = {
	cmd = { 'qmlls' }
}

-- Add this with your other vim.lsp.config configurations
vim.lsp.config['ols'] = {
	cmd = { 'ols' },
	filetypes = { 'odin' },
	capabilities = capabilities,
}

vim.lsp.config['ts_ls'] = {
	cmd = { 'typescript-language-server', '--stdio' },
	filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
	root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
	capabilities = capabilities,
}

vim.lsp.config['clangd'] = {
	cmd = { 'clangd' },
	filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
	root_markers = { 'compile_commands.json', '.clangd', '.git' },
	capabilities = capabilities,
}

vim.lsp.config['pyright'] = {
	cmd = { 'pyright-langserver', '--stdio' },
	filetypes = { 'python' },
	root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' },
	capabilities = capabilities,
}

vim.lsp.config['rust_analyzer'] = {
	cmd = { 'rust-analyzer' },
	filetypes = { 'rust' },
	root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
	capabilities = capabilities,
	settings = {
		['rust-analyzer'] = {
			cargo = {
				allFeatures = true,
			},
			checkOnSave = true,
		},
	},
}

vim.lsp.config.nushell = {
	cmd = { 'nu', '--lsp' },
	filetypes = { 'nu' },
	root_dir = function(fname)
		return vim.fs.dirname(vim.fs.find({ '.git', 'Cargo.toml' }, { upward = true, path = fname })[1])
				or vim.fn.getcwd()
	end,
	capabilities = capabilities,
	settings = {},
}

vim.lsp.config['zls'] = {
	cmd = { 'zls' },
	filetypes = { 'zig', 'zir' },
	root_markers = { 'zls.json', 'build.zig', '.git' },
	capabilities = capabilities,
}

-- Enable LSP servers
vim.lsp.enable({ 'nu', 'fish-lsp', 'leanls', 'ols', 'lua_ls', 'ts_ls', 'clangd', 'pyright',
	'rust_analyzer', 'zls' })

-- Attach on_attach function when LSP attaches
vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client then
			on_attach(client, args.buf)
		end
	end,
})

-- JDTLS setup for Java
local function setup_jdtls()
	local jdtls = require('jdtls')
	local config = {
		cmd = { 'jdtls' },
		root_dir = vim.fs.dirname(vim.fs.find({ '.git', 'mvnw', 'gradlew' }, { upward = true })[1]),
		capabilities = capabilities,
	}
	jdtls.start_or_attach(config)
end

vim.api.nvim_create_autocmd('FileType', {
	pattern = 'java',
	callback = setup_jdtls,
})

-- ToggleTerm setup
require('toggleterm').setup({
	open_mapping = "<C-\\>",
	direction = "float",
	size = 10,
	dir = "current",
	float_opts = {
		winblend = 20,
	},
})

-- LSP Format setup
require("lsp-format").setup {}

require("luasnip").config.set_config({
	history = true,
	updateevents = "TextChanged,TextChangedI",
})

-- CMP Configuration
local cmp = require("cmp")
local mini_icons = require('mini.icons')

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
			local luasnip = require("luasnip")

			if cmp.visible() then
				cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),

		["<S-Tab>"] = cmp.mapping(function(fallback)
			local luasnip = require("luasnip")

			if cmp.visible() then
				cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),

		["<CR>"] = cmp.mapping.confirm({ select = true }),

		["<Up>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
			else
				fallback()
			end
		end, { "i", "s" }),

		["<Down>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
			else
				fallback()
			end
		end, { "i", "s" }),
	}),

	sources = cmp.config.sources({
		{
			name = "nvim_lsp",
			priority = 1000,
			max_item_count = 30,
			entry_filter = function(entry, ctx)
				return true
			end,
		},
		{ name = "buffer", priority = 500, keyword_length = 3, max_item_count = 5 },
		{ name = "path",   priority = 250, max_item_count = 5 },
	}),

	formatting = {
		format = function(entry, vim_item)
			local icon, hl = mini_icons.get('lsp', vim_item.kind)
			vim_item.kind = string.format('%s %s', icon, vim_item.kind)
			vim_item.kind_hl_group = hl
			vim_item.dup = 0
			return vim_item
		end,
	},

	window = {
		completion = cmp.config.window.bordered({
			winhighlight = 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None',
			border = 'rounded', -- Softer borders to blend
		}),
		documentation = cmp.config.window.bordered(),
	},

	experimental = {
		ghost_text = false,
	},

	completion = {
		completeopt = "menu,menuone,noselect",
		autocomplete = {
			require('cmp.types').cmp.TriggerEvent.TextChanged,
		},
	},

	preselect = cmp.PreselectMode.Item,

	performance = {
		debounce = 60,
		throttle = 30,
		fetching_timeout = 500,
	},
})


local autopairs_ok, cmp_autopairs = pcall(require, 'nvim-autopairs.completion.cmp')
if autopairs_ok then
	cmp.event:on(
		'confirm_done',
		cmp_autopairs.on_confirm_done()
	)
end

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

-- rover keymap
vim.keymap.set("v", "<leader>d", ":Rover<CR>", { noremap = true, silent = true })

-- Colorscheme
vim.cmd([[colorscheme gruvbox]])


-- Custom Pmenu highlights with your bg color (#282828)
vim.api.nvim_set_hl(0, 'Pmenu', { bg = '#282828', fg = '#ebdbb2' })    -- Menu items: Your bg + Gruvbox fg for readability
vim.api.nvim_set_hl(0, 'PmenuSel', { bg = '#3c3836', fg = '#fabd2f' }) -- Selection: Subtle bg + yellow accent
vim.api.nvim_set_hl(0, 'PmenuSbar', { bg = '#282828' })                -- Scrollbar: Matches your bg
vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = '#504945' })               -- Thumb: Gruvbox gray for contrast

-- Custom Diagnostic highlights with your bg color (#282828)
vim.api.nvim_set_hl(0, 'DiagnosticFloat', { bg = '#282828', fg = '#ebdbb2' })            -- Float popups: Your bg + neutral fg
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', { bg = '#282828', fg = '#fb4934' }) -- Inline errors: Your bg + red fg
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', { bg = '#282828', fg = '#fabd2f' })  -- Warnings: Your bg + yellow
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { bg = '#282828', fg = '#83a598' })  -- Info: Your bg + blue-green
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', { bg = '#282828', fg = '#b8bb26' })  -- Hints: Your bg + green

-- Underline overrides (for completeness, even if disabled)
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { undercurl = false, underline = false })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { undercurl = false, underline = false })

-- Subtle visible border to match your bg (#282828) without choppiness
vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#504945', bg = '#282828' }) -- fg: Faint Gruvbox gray outline + your bg
-- Fix bg over text in floats: Match your editor bg (#282828)
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = '#282828', fg = '#ebdbb2' }) -- Text area: Your bg + Gruvbox fg (no overlay)
