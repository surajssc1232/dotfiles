-- Plugin Management with Packer
require("packer").startup(function(use)
	use "wbthomason/packer.nvim"
	
	-- Colorschemes
	use "xiyaowong/transparent.nvim"
	use { 'srcery-colors/srcery-vim', as = 'srcery' }
	use "WTFox/jellybeans.nvim"
	use "RRethy/base16-nvim"
	use "blazkowolf/gruber-darker.nvim"
	use { "ellisonleao/gruvbox.nvim" }
	use "sainnhe/gruvbox-material"
	use "bluz71/vim-moonfly-colors"
	use({
		"neanias/everforest-nvim",
		config = function()
			require("everforest").setup()
		end,
	})
	
	-- Core functionality
	use 'Julian/lean.nvim'
	use "surajssc1232/rover.nvim"
	use { "akinsho/toggleterm.nvim", tag = '*', config = function()
		require("toggleterm").setup()
	end }
	
	-- Editor enhancements
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
	use "lukas-reineke/indent-blankline.nvim"
	use 'echasnovski/mini.icons'
	use "kyazdani42/nvim-web-devicons"
	
	-- Telescope
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
	
	-- Treesitter
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
	
	-- LSP and completion
	use "nvim-lua/plenary.nvim"
	use "neovim/nvim-lspconfig"
	use "lukas-reineke/lsp-format.nvim"
	use "hrsh7th/nvim-cmp"
	use "hrsh7th/cmp-buffer"
	use "hrsh7th/cmp-path"
	use "hrsh7th/cmp-nvim-lsp"
	use "L3MON4D3/LuaSnip"
	use 'mfussenegger/nvim-jdtls'
end)

-- Plugin configurations that need to be loaded after packer
require("config.plugin-configs")