return {
	{
		"nvim-treesitter/nvim-treesitter",
		event = "BufReadPre",
		dependencies = {
			"hiphish/rainbow-delimiters.nvim",
		},
		build = ":TSUpdate",
		config = function()
			local configs = require("nvim-treesitter.configs")

			configs.setup({
				ensure_installed = { "lua", "query", "javascript", "typescript", "html", "tsx" },
				sync_install = false,
				highlight = { enable = true },
				indent = { enable = true },
			})

			require("rainbow-delimiters.setup").setup({
				highlight = {
					"RainbowDelimiterYellow",
					"RainbowDelimiterBlue",
					"RainbowDelimiterOrange",
					"RainbowDelimiterGreen",
					"RainbowDelimiterViolet",
					"RainbowDelimiterCyan",
					"RainbowDelimiterRed",
				},
			})
		end,
	},
}
