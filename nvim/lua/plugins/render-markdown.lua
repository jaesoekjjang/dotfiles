return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" },
		ft = { "markdown", "mdx" },
		---@module 'render-markdown'
		---@type render.md.UserConfig
		opts = {
			code = {
				enabled = true,
				style = "full",
				border = "thin",
			},
			inline_code = {
				enabled = true,
				highlight = "RenderMarkdownCodeInline",
			},
			checkbox = {
				enabled = true,
				unchecked = { icon = "󰄱" },
				checked = { icon = "󰄲" },
			},
			heading = {
				enabled = true,
				backgrounds = {
					"RenderMarkdownH1Bg",
					"RenderMarkdownH2Bg",
					"RenderMarkdownH3Bg",
					"RenderMarkdownH4Bg",
					"RenderMarkdownH5Bg",
					"RenderMarkdownH6Bg",
				},
			},
			callout = {
				note      = { raw = "[!NOTE]",      rendered = "󰋽 Note",      highlight = "RenderMarkdownInfo" },
				tip       = { raw = "[!TIP]",        rendered = "󰌶 Tip",        highlight = "RenderMarkdownSuccess" },
				important = { raw = "[!IMPORTANT]",  rendered = "󰅾 Important",  highlight = "RenderMarkdownHint" },
				warning   = { raw = "[!WARNING]",    rendered = "󰀪 Warning",    highlight = "RenderMarkdownWarn" },
				caution   = { raw = "[!CAUTION]",    rendered = "󰳦 Caution",    highlight = "RenderMarkdownError" },
				abstract  = { raw = "[!ABSTRACT]",   rendered = "󰨸 Abstract",   highlight = "RenderMarkdownInfo" },
				summary   = { raw = "[!SUMMARY]",    rendered = "󰨸 Summary",    highlight = "RenderMarkdownInfo" },
				todo      = { raw = "[!TODO]",       rendered = "󰗡 Todo",       highlight = "RenderMarkdownInfo" },
				question  = { raw = "[!QUESTION]",   rendered = "󰘥 Question",   highlight = "RenderMarkdownWarn" },
				failure   = { raw = "[!FAILURE]",    rendered = "󰅖 Failure",    highlight = "RenderMarkdownError" },
				danger    = { raw = "[!DANGER]",     rendered = "󱐌 Danger",     highlight = "RenderMarkdownError" },
				bug       = { raw = "[!BUG]",        rendered = "󰨰 Bug",        highlight = "RenderMarkdownError" },
				example   = { raw = "[!EXAMPLE]",    rendered = "󰉹 Example",    highlight = "RenderMarkdownHint" },
				quote     = { raw = "[!QUOTE]",      rendered = "󱆨 Quote",      highlight = "RenderMarkdownQuote" },
			},
		},
		keys = {
			{ "mr", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle render markdown" },
			-- code block
			{
				"mk",
				function()
					local lang = vim.fn.input("Language: ")
					local row = vim.api.nvim_win_get_cursor(0)[1]
					vim.api.nvim_buf_set_lines(0, row, row, false, { "```" .. lang, "```" })
					vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
					vim.cmd("startinsert!")
				end,
				ft = "markdown",
				desc = "Insert code block",
			},
			-- callout (normal mode only — visual wrap is in markdown-keys.lua)
			{
				"mc",
				function()
					local types = { "NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION", "ABSTRACT", "TODO", "QUESTION", "BUG", "EXAMPLE", "QUOTE" }
					vim.ui.select(types, { prompt = "Callout type:" }, function(choice)
						if not choice then return end
						local row = vim.api.nvim_win_get_cursor(0)[1]
						vim.api.nvim_buf_set_lines(0, row, row, false, { "> [!" .. choice .. "]", "> " })
						vim.api.nvim_win_set_cursor(0, { row + 2, 2 })
						vim.cmd("startinsert!")
					end)
				end,
				ft = "markdown",
				desc = "Insert callout",
			},
			-- list (visual: prefix selected lines with "- ")
			{
				"ml",
				function()
					local s, e = vim.fn.line("'<"), vim.fn.line("'>")
					local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
					local result = {}
					for _, line in ipairs(lines) do
						if line:match("^%s*[-*+] ") or line:match("^%s*%d+%. ") then
							table.insert(result, line)
						else
							table.insert(result, "- " .. line)
						end
					end
					vim.api.nvim_buf_set_lines(0, s - 1, e, false, result)
				end,
				mode = "v",
				ft = "markdown",
				desc = "Make list items",
			},
		},
	},
	{
		"brianhuster/live-preview.nvim",
		ft = { "markdown", "mdx" },
		dependencies = { "nvim-telescope/telescope.nvim" },
		keys = {
			{ "mp", "<cmd>LivePreview start<cr>", ft = "markdown", desc = "Start live preview" },
			{ "mP", "<cmd>LivePreview close<cr>", ft = "markdown", desc = "Close live preview" },
		},
	},
	{
		"davidmh/mdx.nvim",
		config = true,
		dependencies = { "nvim-treesitter/nvim-treesitter" },
	},
}
