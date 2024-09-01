local mapKey = require("utils.keyMapper").mapKey
return {
	{
		"neovim/nvim-lspconfig",

		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},

		config = function()
			local lspconfig = require("lspconfig")
			local masonlsp = require("mason-lspconfig")
			local mason = require("mason")

			-- diagnostic을 hover 메뉴에 표시
			-- K를 누르면 hover에서 아래 또는 위로 이동할 수 있다.
			vim.diagnostic.config({
				virtual_text = false,
				severity_sort = true,
				float = {
					source = "always",
				},
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			local handlers = {
				["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
					silent = true,
				}),
				["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help),
			}

			-- mason
			mason.setup()
			masonlsp.setup({
				ensure_installed = {
					"bashls",
					"lua_ls",
					"html",
					"cssls",
					"jsonls",
					"tsserver",
					"eslint",
					"graphql",
					"tailwindcss",
					"hsl",
				},
				automatic_installation = true,
			})

			masonlsp.setup_handlers({
				function(server_name)
					lspconfig[server_name].setup({
						capabilities = capabilities,
						handlers = handlers,
					})
				end,
			})

			-- emmet
			lspconfig.emmet_ls.setup({
				capabilities = capabilities,
				filetypes = {
					"css",
					"html",
					"javascript",
					"javascriptreact",
					"less",
					"sass",
					"typescript",
					"scss",
					"svelte",
					"pug",
					"typescriptreact",
					"vue",
				},
				init_options = {
					html = {
						options = {
							-- For possible options, see: https://github.com/emmetio/emmet/blob/master/src/config.ts#L79-L267
							["bem.enabled"] = true,
						},
					},
				},
			})

			-- lsp

			-- lua
			lspconfig.lua_ls.setup({
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
					},
				},
			})

			-- typescript
			lspconfig.tsserver.setup({
				capabilities = capabilities,
			})

			lspconfig.eslint.setup({
				settings = {
					codeAction = {
						disableRuleComment = {
							enable = true,
							location = "separateLine",
						},
						showDocumentation = {
							enable = true,
						},
					},
					codeActionOnSave = {
						enable = false,
						mode = "all",
					},
					format = true,
					nodePath = "",
					onIgnoredFiles = "off",
					packageManager = "npm",
					quiet = false,
					rulesCustomizations = {},
					run = "onType",
					useESLintClass = false,
					validate = "on",
					workingDirectory = {
						mode = "location",
					},
				},
				capabilities = capabilities,
			})

			lspconfig.tailwindcss.setup({
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = {
								{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
								{ "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
								"classnames\\(([^)]*)\\)",
							},
						},
					},
				},
			})

			--haskell
			lspconfig.hls.setup({
				filetypes = { "haskell", "lhaskell", "cabal" },
			})

			lspconfig.ccls.setup({})

			-- lsp keymap
			-- float에 focus하려면 <C-w>w
			mapKey("gh", vim.lsp.buf.hover)
			mapKey("gD", vim.lsp.buf.definition)
			mapKey("gq", vim.lsp.buf.code_action)

			mapKey("gd", "<cmd>Telescope lsp_definitions<cr>")
			mapKey("gtd", "<cmd>Telescope lsp_type_definitions<cr>")
			mapKey("gi", "<cmd>Telescope lsp_implementations<cr>")
			mapKey("gr", "<cmd>Telescope lsp_references<cr>")

			mapKey("gl", vim.diagnostic.open_float)
			mapKey("[d", vim.diagnostic.goto_prev)
			mapKey("]d", vim.diagnostic.goto_next)
		end,
	},
	-- {
	-- 	"pmizio/typescript-tools.nvim",
	-- 	dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
	-- 	opts = {},
	-- },
}
