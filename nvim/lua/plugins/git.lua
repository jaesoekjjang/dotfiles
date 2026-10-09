local mapKey = require("utils.keyMapper").mapKey

return {
	{
		"tpope/vim-fugitive",
		config = function()
			mapKey("<space>gg", ":vert G<cr>")
		end,
	},

	{
		"junegunn/gv.vim",
	},

	{
		"idanarye/vim-merginal",
		config = function()
			mapKey("<space>gm", "<cmd>MerginalToggle<cr>")
			vim.g.merginal_windowWidth = math.floor(vim.api.nvim_win_get_width(0) / 2)
		end,
	},

	{
		"akinsho/git-conflict.nvim",
		version = "*",
		opts = {
			default_mappings = {
				ours = "co",
				theirs = "ct",
				both = "cb",
				none = "c0",
				next = "]x",
				prev = "[x",
			},
		},
	},
}
