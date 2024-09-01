local mapKey = require("utils.keyMapper").mapKey
vim.opt.termguicolors = true

return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("bufferline").setup({})

		mapKey("[b", ":BufferLineCyclePrev<CR>", { "n", "i", "c" })
		mapKey("]b", ":BufferLineCycleNext<CR>", { "n", "i", "c" })
	end,
}
