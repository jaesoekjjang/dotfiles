return {
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "insertEnter",
		config = function()
			require("copilot").setup({
				suggestion = {
					auto_trigger = true,
					enabled = false,
				},
				-- panel = { enabled = true },
				filetypes = {
					markdown = true,
					["*"] = true,
				},
			})

			vim.keymap.set("n", "<leader>cs", "<Cmd>Copilot suggestion<CR>", { desc = "Request Copilot Suggestion" })
			vim.keymap.set("n", "<leader>cp", "<Cmd>Copilot panel<CR>", { desc = "Open Copilot Panel" })
		end,
	},
	{
		{
			"CopilotC-Nvim/CopilotChat.nvim",
			dependencies = {
				{ "zbirenbaum/copilot.lua" },
				{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
			},
			build = "make tiktoken", -- Only on MacOS or Linux
			opts = {
				-- See Configuration section for options
			},

			vim.keymap.set("n", "<leader>cc", "<Cmd>CopilotChatToggle<CR>", { desc = "Toggle Copilot Chat" }),
			vim.keymap.set("v", "<leader>cc", "<Cmd>CopilotChat<CR>", { desc = "CopoilotChat with selected context" }),
		},
	},
	{
		"zbirenbaum/copilot-cmp",
		config = function()
			require("copilot_cmp").setup({
				suggestion = { enabled = true },
			})
		end,
	},
}
