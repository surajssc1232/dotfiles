-- LSP servers. Every entry here is enabled automatically, so adding a server
-- is a single table entry -- there is no second list to keep in sync.

local capabilities = require("cmp_nvim_lsp").default_capabilities()

local servers = {
	lua_ls = {
		cmd = { "lua-language-server" },
		filetypes = { "lua" },
		root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
		settings = {
			Lua = { diagnostics = { globals = { "vim" } } },
		},
	},

	["fish-lsp"] = {
		cmd = { "fish-lsp", "start" },
		filetypes = { "fish" },
	},

	ols = {
		cmd = { "ols" },
		filetypes = { "odin" },
	},

	clangd = {
		cmd = { "clangd" },
		filetypes = { "c", "cpp", "objc", "objcpp" },
		root_markers = { "compile_commands.json", ".clangd", ".git" },
	},

	pyright = {
		cmd = { "pyright-langserver", "--stdio" },
		filetypes = { "python" },
		root_markers = { "pyproject.toml", "setup.py", "requirements.txt", ".git" },
	},

	ts_ls = {
		cmd = { "typescript-language-server", "--stdio" },
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
	},

	rust_analyzer = {
		cmd = { "rust-analyzer" },
		filetypes = { "rust" },
		root_markers = { "Cargo.toml", "rust-project.json", ".git" },
		settings = {
			["rust-analyzer"] = {
				cargo = { allFeatures = true },
				checkOnSave = true,
			},
		},
	},

	gopls = {
		cmd = { "gopls" },
		filetypes = { "go", "gomod", "gowork", "gotmpl" },
		root_markers = { "go.work", "go.mod", ".git" },
		settings = {
			gopls = {
				completeUnimported = true,
				usePlaceholders = true,
				staticcheck = true,
				gofumpt = true,
				semanticTokens = true,
				directoryFilters = { "-node_modules" },
				analyses = {
					unusedparams = true,
					unusedvariable = true,
					unusedwrite = true,
					shadow = true,
					nilness = true,
					useany = true,
				},
				hints = {
					assignVariableTypes = true,
					compositeLiteralFields = true,
					compositeLiteralTypes = true,
					constantValues = true,
					functionTypeParameters = true,
					parameterNames = true,
					rangeVariableTypes = true,
				},
			},
		},
	},
}

for name, config in pairs(servers) do
	config.capabilities = capabilities
	vim.lsp.config[name] = config
end

vim.lsp.enable(vim.tbl_keys(servers))

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local opts = { buffer = args.buf, silent = true }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set({ "n", "v" }, "<leader>c", vim.lsp.buf.code_action, opts)

		require("lsp-format").on_attach(client, args.buf)
	end,
})

-- Java is driven by nvim-jdtls rather than vim.lsp.enable, since it needs a
-- fresh client rooted at each project.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "java",
	callback = function()
		require("jdtls").start_or_attach({
			cmd = { "jdtls" },
			root_dir = vim.fs.dirname(vim.fs.find({ ".git", "mvnw", "gradlew" }, { upward = true })[1]),
			capabilities = capabilities,
		})
	end,
})
