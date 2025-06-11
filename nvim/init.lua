-- Leader Key and General Setting-- Leader Key and General Settings
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.fillchars:append { eob = " " }
vim.opt.cursorline = true
vim.opt.laststatus = 0
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.clipboard = "unnamedplus"
vim.opt.wrap = true
vim.opt.updatetime=200 

vim.g.python3_host_prog = '/home/suraj/demo/venv/bin/python3.13'


-- Diagnostics Configuration (hover on cursor hold)
vim.diagnostic.config({
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "false",
        header = "", -- Add a custom header
    	prefix = ""
	},
	signs=false,

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
		event = "VimEnter", -- closest equivalent to "VeryLazy" in packer
	}

    use "wbthomason/packer.nvim"
	use {"akinsho/toggleterm.nvim", tag = '*', config = function()
  		require("toggleterm").setup()
	end}
	
	
	use "ellisonleao/gruvbox.nvim"
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
    use "nvim-telescope/telescope.nvim"
    use "nvim-lua/plenary.nvim"
    use "nvim-treesitter/nvim-treesitter"
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
    use "scottmckendry/cyberdream.nvim"
end)

-- Indent Blankline Configuration
require("ibl").setup({
    indent = { char = "┋" },
    scope = { show_start = false, show_end = false },
})

-- Mason and LSP Configuration
require("mason").setup()
require("mason-lspconfig").setup({ automatic_installation = true })

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local on_attach = function(client, bufnr)
    local opts = { noremap = true, silent = true, buffer = bufnr }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
end

require("mason-lspconfig").setup_handlers({
    function(server_name)
        lspconfig[server_name].setup({
            on_attach = on_attach,
            capabilities = capabilities,
        })
    end,
})


require('toggleterm').setup({
  open_mapping = "<C-\\>",  -- Key mapping for toggling
  direction = "float",      -- Floating window
  size = 20,
  dir = "current",          -- This ensures the terminal opens in the current directory
  float_opts = {
    winblend = 10,           -- Set transparency (0-100)
  }
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
})

-- Nvim-Tree Configuration
require("nvim-tree").setup()
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })

-- Keybindings
vim.keymap.set("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Quit Neovim" })
vim.keymap.set("n", "<leader>w", ":w<CR>", { noremap = true, silent = true })
vim.keymap.set("v", "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set("v", "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set("n", "<leader>r", ":PackerSync<CR>", { noremap = true, silent = true })
-- Colorscheme
vim.cmd([[colorscheme gruvbox]])


