-- LSP Configuration
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local lsp_attached_buffers = {}

-- On attach function
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

-- LSP server configurations
local servers = {
	lua_ls = {
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
	},

	['fish-lsp'] = {
		cmd = { 'fish-lsp', 'start' },
		filetypes = { 'fish' },
		capabilities = capabilities,
	},

	qmlls = {
		cmd = { 'qmlls' }
	},

	ols = {
		cmd = { 'ols' },
		filetypes = { 'odin' },
		capabilities = capabilities,
	},

	ts_ls = {
		cmd = { 'typescript-language-server', '--stdio' },
		filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
		root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
		capabilities = capabilities,
	},

	clangd = {
		cmd = { 'clangd' },
		filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
		root_markers = { 'compile_commands.json', '.clangd', '.git' },
		capabilities = capabilities,
	},

	pyright = {
		cmd = { 'pyright-langserver', '--stdio' },
		filetypes = { 'python' },
		root_markers = { 'pyproject.toml', 'setup.py', 'requirements.txt', '.git' },
		capabilities = capabilities,
	},

	rust_analyzer = {
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
	},

	zls = {
		cmd = { 'zls' },
		filetypes = { 'zig', 'zir' },
		root_markers = { 'zls.json', 'build.zig', '.git' },
		capabilities = capabilities,
	},
}

-- Configure LSP servers
for server, config in pairs(servers) do
	vim.lsp.config[server] = config
end

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
