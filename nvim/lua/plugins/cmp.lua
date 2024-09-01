return {
	{
		"hrsh7th/nvim-cmp",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				version = "v2.*",
				build = "make install_jsregexp",
			},
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lua",
			-- snippets
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-path",
			-- "hrsh7th/cmp-nvim-lsp-signature-help",
			"rafamadriz/friendly-snippets",
			-- "mlaursen/vim-react-snippets",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			local lspconfig = require("lspconfig")
			local types = require("cmp.types")

			-- load snippets
			require("luasnip.loaders.from_vscode").lazy_load()

			local function deprioritize_snippet(entry1, entry2)
				if entry1:get_kind() == types.lsp.CompletionItemKind.Snippet then
					return false
				end
				if entry2:get_kind() == types.lsp.CompletionItemKind.Snippet then
					return true
				end
			end

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
					["<tab>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
					["<C-n>"] = cmp.mapping(
						cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
						{ "i" }
					),
					["<C-p>"] = cmp.mapping(
						cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
						{ "i" }
					),
				}),
				-- autocompletion sources
				sources = cmp.config.sources({
					-- { name = "cmp-nvim-lsp-signature-help" }, -- lsp
					{ name = "nvim_lsp", max_item_count = 50 }, -- lsp
					{ name = "luasnip", max_item_count = 5 }, -- snippets
					{ name = "path", max_item_count = 5 }, -- file system paths
					{ name = "nvim_lua" },
					-- { name = "vim-react-snippets" },
					{ name = "buffer" }, -- text within current buffer
				}),

				sorting = {
					priority_weight = 2,
					comparators = {
						deprioritize_snippet,
						cmp.config.compare.exact,
						cmp.config.compare.offset,
						cmp.config.compare.scopes,
						cmp.config.compare.score,
						cmp.config.compare.recently_used,
						cmp.config.compare.locality,
						cmp.config.compare.kind,
						cmp.config.compare.sort_text,
						cmp.config.compare.length,
						cmp.config.compare.order,
					},
				},

				experimental = {
					ghost_text = true,
				},
			})

			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{ name = "cmdline" },
				}),
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			lspconfig.tsserver.setup({
				capabilities = capabilities,
			})
		end,
	},
}
