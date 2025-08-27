return {
	"nvim-tree/nvim-tree.lua",
	config = function()
		require("nvim-tree").setup({})

		vim.api.nvim_set_keymap("n", "<leader>en", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
	end,
}
