return {
	{
		"stevearc/conform.nvim",
		event = { "LspAttach", "BufReadPost", "BufNewFile" },
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				css = { "prettierd", "prettier", stop_after_first = true },
				scss = { "prettierd", "prettier", stop_after_first = true },
				json = { "prettierd", "prettier", stop_after_first = true },
				yaml = { "prettierd", "prettier", stop_after_first = true },
				html = { "prettierd", "prettier", stop_after_first = true },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },
				c = { "clang_format" },
				haskell = { "ormolu" },
				python = { "autopep8" },
			},
			formatters = {
				autopep8 = {
					command = function()
						if vim.fn.executable("autopep8") == 1 then
							return "autopep8"
						end
						local mason = vim.fn.stdpath("data") .. "/mason/packages/python-lsp-server/venv/bin/autopep8"
						return vim.fn.executable(mason) == 1 and mason or "autopep8"
					end,
				},
			},
			-- format_on_save = {
			-- 	timeout_ms = 500,
			-- 	lsp_fallback = true,
			-- },
			lang_to_ext = {
				bash = { "sh", "bash" },
				typescript = { "ts", "tsx" },
				javascript = { "js", "jsx" },
				haskell = { "hs" },
				python = { "py" },
			},
		},
		config = function(_, opts)
			local conform = require("conform")

			conform.setup(opts)

			vim.keymap.set("n", "<leader>cf", function()
				conform.format({ async = true })
			end)
		end,
	},
}
