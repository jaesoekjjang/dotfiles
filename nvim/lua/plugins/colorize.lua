return {
	"norcalli/nvim-colorizer.lua",
	config = function()
		require("colorizer").setup({
			filetypes = {
				"html",
				css = {
					hsl_fn = true,
					rgb_fn = true,
				},
				"javascript",
				"typescript",
				"typescriptreact",
				"javascriptreact",
				"lua",
			},
		})
	end,
}
