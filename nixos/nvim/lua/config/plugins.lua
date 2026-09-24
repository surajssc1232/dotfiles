-- Plugin declarations. Each plugin is configured right where it is declared,
-- so there is one place to look per plugin. The single exception is nvim-cmp,
-- which is long enough to live in config/completion.lua.

-- lazy.nvim installs itself on first start; after that it lives in the data
-- directory, which Nix leaves alone.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	-- Colorschemes. gruvbox-material is the active one (set in
	-- colorscheme.lua); the rest are here to switch between.
	{ "sainnhe/gruvbox-material", priority = 1000 },
	"ellisonleao/gruvbox.nvim",
	"xiyaowong/transparent.nvim",
	{ "srcery-colors/srcery-vim", name = "srcery" },
	"WTFox/jellybeans.nvim",
	"blazkowolf/gruber-darker.nvim",
	"shaunsingh/nord.nvim",
	"bluz71/vim-moonfly-colors",
	{
		"neanias/everforest-nvim",
		config = function()
			require("everforest").setup({})
		end,
	},

	-- Icons, shared by lualine, nvim-tree and the completion menu.
	{
		"echasnovski/mini.icons",
		config = function()
			require("mini.icons").setup()
		end,
	},

	{
		"nvim-lualine/lualine.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		config = function()
			require("lualine").setup({
				options = {
					theme = "auto",
					component_separators = { left = "", right = ""},
					section_separators = { left = "", right = ""},
				},
			})
		end,
	},

	{
		"nvim-tree/nvim-tree.lua",
		config = function()
			require("nvim-tree").setup()
		end,
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		config = function()
			require("ibl").setup({
				indent = { char = "|" },
				scope = { show_start = false, show_end = false },
			})
		end,
	},

	{
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
	},

	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = function()
			require("toggleterm").setup({
				open_mapping = "<C-\\>",
				direction = "float",
				size = 10,
				dir = "current",
				float_opts = { winblend = 20 },
			})
		end,
	},

	-- Gemini-backed assistant. The key is read from the environment so it
	-- stays out of this file (and out of the world-readable Nix store).
	{
		"surajssc1232/rover.nvim",
		config = function()
			require("rover").setup({
				api_key = os.getenv("GEMINI_API_KEY"),
				model = "gemini-2.5-flash",
				window_width = 150,
				window_height = 25,
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			local actions = require("telescope.actions")
			require("telescope").setup({
				defaults = {
					mappings = {
						i = {
							["<C-j>"] = actions.move_selection_next,
							["<C-k>"] = actions.move_selection_previous,
						},
					},
				},
			})
		end,
	},

	-- On this branch of nvim-treesitter, highlighting and indentation are
	-- Neovim features that have to be switched on per filetype.
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		build = ":TSUpdate",
		config = function()
			local langs =
				{ "lua", "python", "javascript", "c", "elixir", "eex", "heex", "java", "rust", "zig" }
			require("nvim-treesitter").install(langs)

			vim.api.nvim_create_autocmd("FileType", {
				pattern = langs,
				callback = function(args)
					pcall(vim.treesitter.start)
					-- Runtime ftplugins set indentexpr after FileType fires,
					-- so claim it back once they are done.
					vim.schedule(function()
						if vim.api.nvim_buf_is_valid(args.buf) then
							vim.bo[args.buf].indentexpr =
								"v:lua.require'nvim-treesitter'.indentexpr()"
						end
					end)
				end,
			})
		end,
	},

	-- LSP and completion. Servers are configured in config/lsp.lua and the
	-- completion menu in config/completion.lua.
	"neovim/nvim-lspconfig",
	"mfussenegger/nvim-jdtls",
	{
		"lukas-reineke/lsp-format.nvim",
		config = function()
			require("lsp-format").setup({})
		end,
	},
	{
		"L3MON4D3/LuaSnip",
		config = function()
			require("luasnip").config.set_config({
				history = true,
				updateevents = "TextChanged,TextChangedI",
			})
		end,
	},
	"hrsh7th/nvim-cmp",
	"hrsh7th/cmp-nvim-lsp",
	"hrsh7th/cmp-buffer",
	"hrsh7th/cmp-path",
}, {
	-- Keep the runtimepath the Nix neovim wrapper sets up rather than letting
	-- lazy reset it to its defaults.
	performance = { rtp = { reset = false } },
	-- The config directory is rebuilt by Nix, so the lockfile lives with the
	-- plugins instead.
	lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
})

-- lazy loads a plugin's module on first require, so this works even though
-- the completion plugins are declared above.
pcall(require, "config.completion")
