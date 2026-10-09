return {
	"mikavilpas/yazi.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	keys = {
		{
			"<leader>e",
			function()
				require("yazi").yazi()
			end,
			desc = "Open yazi file manager",
		},
		{
			"<leader>E",
			function()
				require("yazi").yazi(nil, vim.fn.getcwd())
			end,
			desc = "Open yazi in cwd",
		},
	},
	opts = {
		open_for_directories = true,
		floating_window_scaling_factor = 0.9,
		yazi_floating_window_winblend = 0,
		log_level = vim.log.levels.OFF,
		open_multiple_tabs = false,
		yazi_floating_window_border = "rounded",
	},
}
