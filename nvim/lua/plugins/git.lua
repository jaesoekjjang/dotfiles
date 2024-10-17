local mapKey = require("utils.keyMapper").mapKey

return {
	{
		"tpope/vim-fugitive",
		config = function()
			mapKey("<space>g", ":vertical G<cr>")
		end,
	},
	{
		"junegunn/gv.vim",
	},
	{
		"kdheepak/lazygit.nvim",
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		-- optional for floating window border decoration
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
	},
}
