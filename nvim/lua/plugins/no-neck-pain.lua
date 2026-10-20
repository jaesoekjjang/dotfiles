return {
	"shortcuts/no-neck-pain.nvim",
	version = "*",
	lazy = false,
	keys = {
		{ "<leader>lc", "<cmd>NoNeckPain<cr>", desc = "Center layout" },
	},
	opts = {
		width = 145,
		autocmds = {
			enableOnVimEnter = "safe",
			enableOnTabEnter = true,
		},
	},
}
