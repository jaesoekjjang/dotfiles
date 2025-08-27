local mapKey = require("utils.keyMapper").mapKey
return {
	{
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

				vim.diagnostic.config({
					virtual_text = false,
					severity_sort = true,
					float = {
						source = true,
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
						"eslint",
						"graphql",
						"tailwindcss",
						"hls",
						"ts_ls",
            "gopls",
            "marksman"
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
						"typescriptreact",
						"vue",
						"scss",
						"pug",
						"ml",
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
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								checkThirdParty = false,
							},
						},
					},
				})

				-- typescript
				lspconfig.ts_ls.setup({
					capabilities = capabilities,
					settings = {
						implicitProjectConfiguration = {
							checkJs = false,
						},
						root_dir = function(fname)
							return lspconfig.util.root_pattern("tsconfig.json", "jsconfig.json")(fname)
						end,
					},
				})

				lspconfig.flow.setup({
					capabilities = capabilities,
					settings = {
						filetypes = { "*.js", "*.jsx", "*.ts", "*.tsx" },
						root_dir = lspconfig.util.root_pattern(".flowconfig.js", "flow-typed", "package.json"),
					},
				})

				lspconfig.vuels.setup({})

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
						includeLanguages = {
							typescript = "javascript",
							typescriptreact = "javascript",
						},
						tailwindCSS = {
							classFunctions = { "tw", "clsx", "tw\\.[a-z-]+", "classnames\\(([^)]*)\\)" },
							experimental = {
								classRegex = {
									{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
									{ "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
									"classnames\\(([^)]*)\\)",
									-- Direct string assignment patterns
									{ "\\w*[cC]lassName\\s*=\\s*[\"'`]([^\"'`]*)[\"'`]" },
									{ "\\w*[cC]lassNames\\s*=\\s*[\"'`]([^\"'`]*)[\"'`]" },
									-- Object property value patterns
									{ "\\w*[cC]lassNames\\s*=\\s*{([^}]*)}", "[\"'`]([^\"'`]*)[\"'`]" },
									{ "\\w*[cC]lassName\\s*:\\s*[\"'`]([^\"'`]*)[\"'`]" },
									-- Generic object patterns
									{ "\\w+\\s*=\\s*{([^}]*)}", "[\"'`]([^\"'`]*)[\"'`]" },
									{ "\\w+\\s*:\\s*[\"'`]([^\"'`]*)[\"'`]" },
								},
							},
						},
					},
				})

				-- c, cpp
				lspconfig.ccls.setup({})

				-- haskell
				lspconfig.hls.setup({})

				-- ocaml
				lspconfig.ocamllsp.setup({})

				-- python
				lspconfig.pylsp.setup({
					capabilities = capabilities,
					settings = {
						pylsp = {
							plugins = {
								pycodestyle = {
									ignore = { "W391" },
									maxLineLength = 100,
								},
							},
						},
					},
				})

        lspconfig.marksman.setup({
          capabilities = capabilities,
          filetypes = { "markdown" },
        })

			end,
		},
	},
}
