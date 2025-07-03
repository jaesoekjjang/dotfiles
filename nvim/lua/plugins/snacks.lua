return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = { enabled = true },
		dashboard = { enabled = false },
		explorer = { enabled = false },
		indent = { enabled = false },
		input = { enabled = false },
		picker = { enabled = false },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = false },
		win = {
			width = 1,
			height = 1,
		},
	},
	keys = {
		{
			"<leader>gl",
			function()
				Snacks.lazygit()
			end,
			desc = "Lazygit",
		},
	},
	config = function()
		vim.api.nvim_create_autocmd("TermOpen", {
			pattern = "*",
			callback = function()
				local term_title = vim.b.term_title
				if term_title and term_title:match("lazygit") then
					vim.keymap.set("t", "<leader>gl", "<cmd>close<cr>", { buffer = true, desc = "Lazygit" })
				end
			end,
		})
	end,
}
