return {
	{
		"neovim/nvim-lspconfig",
		version = "^2.0.0",
		dependencies = {
			{ "mason-org/mason.nvim", version = "^2.0.0" },
			{ "mason-org/mason-lspconfig.nvim", version = "^2.0.0" },
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			vim.diagnostic.config({ virtual_text = false, severity_sort = true, float = { source = true } })
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			vim.lsp.config("*", { capabilities = capabilities })
			-- emmet
			vim.lsp.config("emmet_ls", {
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
			vim.lsp.config("lua_ls", {
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
			vim.lsp.config("ts_ls", {
				capabilities = capabilities,
				root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
				settings = {
					implicitProjectConfiguration = {
						checkJs = false,
					},
				},
			})

			vim.lsp.config("flow", {
				capabilities = capabilities,
				filetypes = { "javascript", "javascriptreact" },
				root_markers = { ".flowconfig", ".flowconfig.js" },
			})

			vim.lsp.config("vue_ls", {})
			vim.lsp.config("ts_ls", {
				filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
				init_options = {
					plugins = {
						{
							name = "@vue/typescript-plugin",
							location = vim.fn.stdpath("data")
								.. "/mason/packages/vue-language-server/node_modules/@vue/typescript-plugin",
							languages = { "vue" },
						},
					},
				},
			})

			vim.lsp.config("eslint", {
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

			vim.lsp.config("tailwindcss", {
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
			vim.lsp.config("ccls", {})

			-- haskell
			vim.lsp.config("hls", {})

			-- ocaml
			vim.lsp.config("ocamllsp", {})

			-- python
			vim.lsp.config("pylsp", {
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

			vim.lsp.config("marksman", {
				capabilities = capabilities,
				filetypes = { "markdown" },
			})

			-- Kubernetes manifests and Helm charts
			vim.lsp.config("yamlls", {
				capabilities = capabilities,
				settings = {
					yaml = {
						kubernetes = { enabled = true },
					},
				},
			})

			vim.lsp.config("helm_ls", {
				capabilities = capabilities,
			})

			local managed = {
				"bashls",
				"lua_ls",
				"html",
				"cssls",
				"jsonls",
				"eslint",
				"graphql",
				"tailwindcss",
				"ts_ls",
				"gopls",
				"marksman",
				"yamlls",
				"helm_ls",
				"vue_ls",
				"emmet_ls",
				"pylsp",
			}
			require("mason").setup()
			require("mason-lspconfig").setup({ ensure_installed = managed, automatic_enable = managed })
			require("mason-tool-installer").setup({
				ensure_installed = { "stylua", "prettierd", "prettier", "clang-format", "autopep8" },
				auto_update = false,
				run_on_start = true,
			})
			-- Optional languages keep their configs without startup install/failure.
			local optional = {
				flow = "flow",
				ccls = "ccls",
				ocamllsp = "ocamllsp",
				hls = "haskell-language-server-wrapper",
			}
			for server, executable in pairs(optional) do
				if vim.fn.executable(executable) == 1 then
					vim.lsp.enable(server)
				end
			end
		end,
	},
}
