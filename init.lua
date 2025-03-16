--leader key
vim.g.mapleader=" "

--line numbers
vim.opt.number=true

vim.o.laststatus = 0

--cursor line
vim.opt.cursorline=true

--set tab width
vim.opt.tabstop=4
vim.opt.shiftwidth=4
vim.opt.expandtab=true

vim.opt.clipboard="unnamedplus"

require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'

    -- Example plugins
    use 'nvim-tree/nvim-tree.lua'       -- File explorer
    use 'nvim-lualine/lualine.nvim'     -- Statusline
    use 'folke/tokyonight.nvim'         -- Color scheme
    use 'neovim/nvim-lspconfig'         -- LSP configuration
    use 'kyazdani42/nvim-web-devicons'
    use 'williamboman/mason.nvim'
    use 'williamboman/mason-lspconfig.nvim'
    use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
    use 'hrsh7th/cmp-buffer' -- Buffer source for nvim-cmp
    use 'hrsh7th/cmp-path' -- Path source for nvim-cmp
    use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
    use 'onsails/lspkind.nvim' -- Adds icons to LSP suggestions
end)


-- Autocompletion setup
local cmp = require("cmp")
local lspkind=require("lspkind")
cmp.setup({
    snippet = {
        expand = function(args)
            -- Use a snippet engine like luasnip if needed
            -- vim.fn["vsnip#anonymous"](args.body)
        end,
    },
    mapping = cmp.mapping.preset.insert({
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp" }, -- LSP suggestions
        { name = "buffer" },  -- Suggestions from current buffer
        { name = "path" },-- File path suggestions
        { name = "cmdline" },
    }),
    formatting = {
        format = lspkind.cmp_format({
            mode = "symbol_text", -- Show both icons and text
            maxwidth = 50,        -- Prevent the menu from being too wide
            ellipsis_char = "...", -- Show "..." for long items
            with_text = true,     -- Ensure text is included after the icon
        }),
    },
})

require('nvim-tree').setup()
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

require('lualine').setup({
    options = {
        theme = 'tokyonight',
    },
})

require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed={},
    automatic_installation=true,
})

-- LSP configuration
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


vim.keymap.set('n', '<leader>q', ':q<CR>', { noremap = true, silent = true, desc = "Quit Neovim" })
vim.keymap.set('n','<leader>w',':w<CR>',{noremap=true,silent=true})
vim.keymap.set('v', '<leader>y', '"+y', { noremap = true, silent = true })
vim.keymap.set('v', '<leader>p', '"+p', { noremap = true, silent = true })
vim.keymap.set('n','<leader>r',':PackerSync<CR>',{noremap= true, silent=true})
vim.cmd[[colorscheme tokyonight]]

