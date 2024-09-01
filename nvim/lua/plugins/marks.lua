return {
	"chentoast/marks.nvim",
	config = function()
		require("marks").setup({
			sign_priority = { bookmark = 0 },
		})
	end,
}
