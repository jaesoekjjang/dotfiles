local mapKey = require("utils.keyMapper").mapKey
vim.opt.termguicolors = true

return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("bufferline").setup({})

		mapKey("[b", "<Cmd>BufferLineCyclePrev<CR>", { "n", "i", "c" }, { desc = "Previous buffer" })
		mapKey("]b", "<Cmd>BufferLineCycleNext<CR>", { "n", "i", "c" }, { desc = "Next buffer" })
	end,
}
