return {
	{
		"stevearc/conform.nvim",
		event = { "LspAttach", "BufReadPost", "BufNewFile" },
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				css = { "prettierd", "prettier" },
				json = { "prettierd", "prettier" },
				yaml = { "prettierd", "prettier" },
				javascript = { "prettierd", "prettier" },
				typescript = { "prettierd", "prettier" },
				javascriptreact = { "prettierd", "prettier" },
				typescriptreact = { "prettierd", "prettier", "stop_after_first" },
				c = { "clang_format" },
				haskell = { "hindent" },
			},
			-- format_on_save = {
			-- 	timeout_ms = 500,
			-- 	lsp_fallback = true,
			-- },
			lang_to_ext = {
				bash = "sh",
				typescript = { "ts", "tsx" },
				javascript = { "js", "jsx" },
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
