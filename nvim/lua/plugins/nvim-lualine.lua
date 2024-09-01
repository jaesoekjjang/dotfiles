return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("lualine").setup({
			options = {
				theme = "gruvbox-material",
			},
			sections = {
				lualine_c = {
					{ "filename", path = 4 },
				},
			},
		})
	end,
}
