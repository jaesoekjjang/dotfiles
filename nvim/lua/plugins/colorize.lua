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
        'scss',
				"javascript",
				"typescript",
				"typescriptreact",
				"javascriptreact",
				"vue",
				"lua",
			},
		})
	end,
}
