-- Individual plugin configurations
-- Mini.icons setup
require('mini.icons').setup()
-- Indent Blankline Configuration
require("ibl").setup({
	indent = { char = "┋" },
	scope = { show_start = false, show_end = false },
})
-- Rover setup
require('rover').setup({
	api_key = "AIzaSyC27VXi-WRBetfH3lZCMmGTIzbnxBPRzPQ",
	window_width = 150,
	window_height = 25,
	model = 'gemini-2.5-flash'
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
-- LuaSnip configuration
require("luasnip").config.set_config({
	history = true,
	updateevents = "TextChanged,TextChangedI",
})
-- Nvim-Tree Configuration
require("nvim-tree").setup()
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
			
			-- Auto-add parenthesis for functions/methods
			if vim_item.kind == "Function" or vim_item.kind == "Method" then
				if not vim_item.abbr:match("%(") then  -- Only add if not already present
					vim_item.abbr = vim_item.abbr .. "()"
				end
			end
			
			vim_item.kind = string.format('%s %s', icon, vim_item.kind)
			vim_item.kind_hl_group = hl
			vim_item.dup = 0
			
			-- THIS IS THE ONLY THING THAT ACTUALLY LIMITS WIDTH NOW
			local MAX_ABBR = 50   -- change this number to whatever you want
			local MAX_MENU = 30   -- for the [LSP] / [Buffer] part on the right
			
			if vim_item.abbr and #vim_item.abbr > MAX_ABBR then
				vim_item.abbr = vim_item.abbr:sub(1, MAX_ABBR - 3) .. "..."
			end
			
			if vim_item.menu and #vim_item.menu > MAX_MENU then
				vim_item.menu = vim_item.menu:sub(1, MAX_MENU - 3) .. "..."
			end
			
			return vim_item
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
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
-- Autopairs integration with cmp
local autopairs_ok, cmp_autopairs = pcall(require, 'nvim-autopairs.completion.cmp')
if autopairs_ok then
	cmp.event:on(
		'confirm_done',
		cmp_autopairs.on_confirm_done()
	)
end
