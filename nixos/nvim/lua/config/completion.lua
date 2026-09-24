-- nvim-cmp. Split out from plugins.lua because it is the one plugin whose
-- configuration is long enough to drown out everything around it.

local cmp = require("cmp")
local luasnip = require("luasnip")
local icons = require("mini.icons")

local insert = { behavior = cmp.SelectBehavior.Insert }

-- Arrows only walk the completion menu.
local function menu_only(select_item)
	return cmp.mapping(function(fallback)
		if cmp.visible() then
			select_item(insert)
		else
			fallback()
		end
	end, { "i", "s" })
end

-- Tab walks the menu, and falls through to snippet placeholders when closed.
local function menu_or_snippet(select_item, can_jump, jump)
	return cmp.mapping(function(fallback)
		if cmp.visible() then
			select_item(insert)
		elseif can_jump() then
			jump()
		else
			fallback()
		end
	end, { "i", "s" })
end

local MAX_ABBR = 50 -- completion item text
local MAX_MENU = 30 -- the [LSP] / [Buffer] tag on the right

local function truncate(text, limit)
	if text and #text > limit then
		return text:sub(1, limit - 3) .. "..."
	end
	return text
end

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},

	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
		["<Down>"] = menu_only(cmp.select_next_item),
		["<Up>"] = menu_only(cmp.select_prev_item),
		["<Tab>"] = menu_or_snippet(cmp.select_next_item, function()
			return luasnip.expand_or_jumpable()
		end, function()
			luasnip.expand_or_jump()
		end),
		["<S-Tab>"] = menu_or_snippet(cmp.select_prev_item, function()
			return luasnip.jumpable(-1)
		end, function()
			luasnip.jump(-1)
		end),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp", priority = 1000, max_item_count = 30 },
		{ name = "buffer", priority = 500, max_item_count = 5, keyword_length = 3 },
		{ name = "path", priority = 250, max_item_count = 5 },
	}),

	formatting = {
		format = function(_, item)
			-- Functions and methods get their parentheses shown.
			if (item.kind == "Function" or item.kind == "Method") and not item.abbr:match("%(") then
				item.abbr = item.abbr .. "()"
			end

			local icon, hl = icons.get("lsp", item.kind)
			item.kind = string.format("%s %s", icon, item.kind)
			item.kind_hl_group = hl
			item.dup = 0

			item.abbr = truncate(item.abbr, MAX_ABBR)
			item.menu = truncate(item.menu, MAX_MENU)
			return item
		end,
	},

	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},

	completion = { completeopt = "menu,menuone,preview,noselect" },
	preselect = cmp.PreselectMode.None,

	performance = {
		debounce = 60,
		throttle = 30,
		fetching_timeout = 500,
	},
})

-- Insert closing brackets after confirming a function completion.
local ok, autopairs = pcall(require, "nvim-autopairs.completion.cmp")
if ok then
	cmp.event:on("confirm_done", autopairs.on_confirm_done())
end
