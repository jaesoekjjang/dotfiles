return {
	"shortcuts/no-neck-pain.nvim",
	config = function()
		require("lazy").setup({ { "shortcuts/no-neck-pain.nvim", version = "*" } })
		require("no-neck-pain").setup({
			width = 180,
		})
	end,
}
