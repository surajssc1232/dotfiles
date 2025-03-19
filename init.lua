-- Leader Key
vim.g.mapleader = " "

-- General Settings
vim.o.wrap = true -- Wrap lines if they exceed the window width
vim.opt.number = true -- Enable line numbers
vim.opt.cursorline = true -- Highlight the current line
vim.opt.tabstop = 4 -- Set tab width to 4 spaces
vim.opt.shiftwidth = 4 -- Indentation width
vim.opt.expandtab = true -- Convert tabs to spaces
vim.opt.clipboard = "unnamedplus" -- Use system clipboard
vim.o.laststatus = 0 -- Disable statusline
vim.o.updatetime = 300 -- Adjust delay for diagnostics hover

-- Statusline
vim.o.statusline = '%f\\ %h%m%r%=%l:%c\\ %P'

-- Diagnostics Configuration
vim.diagnostic.config({
    virtual_text=false,
    float = {
        focusable = false, -- Make the floating window non-focusable
        style = "minimal", -- Use a minimal style
        border = "rounded", -- Add rounded borders
        source = false, -- Always show the diagnostic source (e.g., "eslint", "pyright")
        header = "", -- No header
        prefix = "", -- No prefix
    },
    signs=false,
})

-- Keybindings for Diagnostics
vim.keymap.set('n', '<leader>d', function()
    vim.diagnostic.open_float(nil, { scope = "cursor", focusable = false })
end, { noremap = true, silent = true, desc = "Show diagnostics in floating window" })

--Automatically show diagnostics on hover
vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        local float_opts = {
            focusable = false,
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            border = 'rounded',
            source = false,
            prefix = '',
            scope = "cursor",
        }
        vim.diagnostic.open_float(nil, float_opts)
    end
})

--autopairs


-- Plugin Management with Packer
require('packer').startup(function(use)
    -- Packer manages itself
    use 'wbthomason/packer.nvim'
    
    use{
        'windwp/nvim-autopairs',
        event='InsertEnter',
        config=function ()
            require('nvim-autopairs').setup({
                check_ts=true,
                enable_check_bracket_line=true,
                ignored_next_chars="[%w%.]",
                map_cr=true,
                map_bs=true,
            })
            
        end
    }
    -- File Explorer
    use 'nvim-tree/nvim-tree.lua'

    -- Telescope (Fuzzy Finder)
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-lua/plenary.nvim' -- Required dependency

    -- Treesitter (Syntax Highlighting)
    use 'nvim-treesitter/nvim-treesitter'

    -- LSP and Autocompletion
    use 'neovim/nvim-lspconfig'
    use 'williamboman/mason.nvim'
    use 'williamboman/mason-lspconfig.nvim'
    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-buffer' -- Buffer source for nvim-cmp
    use 'hrsh7th/cmp-path' -- Path source for nvim-cmp
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'onsails/lspkind.nvim' -- Adds icons to LSP suggestions

    -- Snippets
    use 'L3MON4D3/LuaSnip'

    -- UI Enhancements
    use 'kyazdani42/nvim-web-devicons'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'akinsho/toggleterm.nvim'

    -- Themes
    use 'scottmckendry/cyberdream.nvim'
    use 'shaunsingh/nord.nvim'
    use 'folke/tokyonight.nvim'
end)

-- Indent Blankline Configuration
require('ibl').setup({
    indent = { char = "┋" },
    scope = {
        show_start = false,
        show_end = false,
    },
})

-- Treesitter Configuration
require('nvim-treesitter.configs').setup({
    ensure_installed = { "c", "cpp", "python", "javascript", "typescript", "rust", "lua", "html", "css" },
    highlight = { enable = true },
    indent = { enable = true },
    autotag = { enable = true },
    textobjects = {
        select = {
            enable = true,
            lookahead = true,
            keymaps = {
                ['af'] = '@function.outer',
                ['if'] = '@function.inner',
                ['ac'] = '@class.outer',
                ['ic'] = '@class.inner',
            },
        },
    },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = '<CR>',
            node_incremental = '<CR>',
            node_decremental = '<BS>',
        },
    },
    fold = { enable = true },
})

-- Autocompletion Setup
local cmp = require("cmp")
local lspkind = require("lspkind")

cmp.setup({
    snippet = {
        expand = function(args)
            require("luasnip").lsp_expand(args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<M-a>"] = cmp.mapping.scroll_docs(-4),
        ["<M-d>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" }, -- LSP suggestions
        { name = "buffer" },  -- Suggestions from current buffer
        { name = "path" },    -- File path suggestions
        { name = "cmdline" },
    }),
    formatting = {
        format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            with_text = true,
        }),
    },
})

-- Nvim-Tree Configuration
require('nvim-tree').setup()
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Telescope Configuration
require('telescope').setup({
    defaults = {
        layout_strategy = "horizontal",
        layout_config = {
            width = 0.9,
            height = 0.8,
        },
    },
})

-- Mason and LSP Configuration
require("mason").setup()
require("mason-lspconfig").setup({
    automatic_installation = true,
})

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

-- ToggleTerm Configuration
require("toggleterm").setup({
    size = 20,
    open_mapping = [[<c-\>]],
    hide_numbers = true,
    shade_filetypes = {},
    shade_terminals = true,
    shading_factor = 2,
    start_in_insert = true,
    persist_size = true,
    direction = 'float',
})



-- Keybindings
vim.keymap.set('n', '<leader>ff', '<cmd>Telescope find_files<cr>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>fb', '<cmd>Telescope buffers<cr>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', { noremap = true, silent = true })

vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<cr>', { noremap = true, silent = true })
vim.keymap.set('t', '<leader>tt', '<cmd>ToggleTerm<cr>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>th', '<cmd>ToggleTerm size=20 direction=horizontal<cr>', { noremap = true, silent = true })

vim.keymap.set('n', '<leader>q', ':q<CR>', { noremap = true, silent = true, desc = "Quit Neovim" })
vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true, silent = true })
vim.keymap.set('v', '<leader>y', '"+y', { noremap = true, silent = true })
vim.keymap.set('v', '<leader>p', '"+p', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>r', ':PackerSync<CR>', { noremap = true, silent = true })

-- Trouble Keybindings
vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>", { silent = true, noremap = true })
vim.keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", { silent = true, noremap = true })
vim.keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", { silent = true, noremap = true })

-- Colorscheme
vim.cmd([[colorscheme cyberdream]])
vim.cmd([[filetype plugin indent on]])
