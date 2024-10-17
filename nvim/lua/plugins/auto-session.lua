return {
	"rmagatti/auto-session",
	lazy = false,
	dependencies = {
		"nvim-telescope/telescope.nvim", -- Only needed if you want to use session lens
	},
  keys = {
    { '<leader>ss', '<cmd>SessionSearch<CR>', desc = 'Session search' },
    { '<leader>sw', '<cmd>SessionSave<CR>', desc = 'Save session' },
  },

	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
		-- log_level = 'debug',
	},
}
