return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		dependencies = { "hiphish/rainbow-delimiters.nvim" },
		build = ":TSUpdate",
		config = function()
			-- Long-running terminal/daemon sessions may still inherit a removed
			-- compiler wrapper after setup. Let tree-sitter use the system compiler.
			if vim.env.CC and vim.fn.executable(vim.env.CC) == 0 then
				vim.env.CC = nil
			end
			local treesitter = require("nvim-treesitter")
			-- Prefer current parsers and queries over files left by the legacy branch.
			treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
			treesitter.install({
				"lua",
				"vim",
				"query",
				"javascript",
				"typescript",
				"html",
				"tsx",
				"vue",
				"haskell",
				"c",
				"python",
				"markdown",
				"markdown_inline",
				"yaml",
				"helm",
				"gotmpl",
			})
			local group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				callback = function(args)
					-- Unsupported filetypes keep normal syntax and indentation.
					local ok, parser = pcall(vim.treesitter.get_parser, args.buf)
					if ok and parser then
						vim.treesitter.start(args.buf)
						vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
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
