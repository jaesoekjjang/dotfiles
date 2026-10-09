return {
	"rmagatti/auto-session",
	lazy = false,
	dependencies = {
		"folke/snacks.nvim",
	},
	keys = {
		{ "<leader>ss", "<cmd>AutoSession search<CR>", desc = "Session search" },
		{ "<leader>sS", "<cmd>AutoSession save<CR>", desc = "Save session" },
	},

	---enables autocomplete for opts
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		session_lens = { picker = "snacks" },
		-- log_level = 'debug',
	},
}
