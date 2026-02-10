-- VSCode 환경에서 필요한 최소한의 플러그인들만 로드

return {
	-- 텍스트 편집 유틸리티
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({
				keymaps = {
					-- VSCode에서 충돌할 수 있는 키맵들 비활성화
					insert = false,
					insert_line = false,
					normal = "ys",
					normal_cur = "yss",
					normal_line = "yS",
					normal_cur_line = "ySS",
					visual = "S",
					visual_line = "gS",
					delete = "ds",
					change = "cs",
					change_line = "cS",
				},
				surrounds = {
					["v"] = {
						add = function()
							-- VSCode surround.with 호출
							vim.fn.VSCodeNotify("surround.with")
							return false
						end,
					},
				},
			})
		end,
	},
	{
		"numToStr/Comment.nvim",
		config = function() end,
	},

	{
		name = "oil-code-keymaps",
		dir = vim.fn.stdpath("config"),
		config = function()
			if vim.g.vscode then
				local vscode = require("vscode")
				local map = vim.keymap.set

				vim.api.nvim_create_autocmd({ "FileType" }, {
					pattern = { "oil" },
					callback = function(ev)
						local opts = { buffer = ev.buf }
						map("n", "-", function()
							vscode.action("oil-code.openParent")
						end, opts)
						map("n", "_", function()
							vscode.action("oil-code.openCwd")
						end, opts)
						map("n", "<CR>", function()
							vscode.action("oil-code.select")
						end, opts)
						map("n", "<C-v>", function()
							vscode.action("oil-code.selectVertical")
						end, opts)
						map("n", "<C-r>", function()
							vscode.action("oil-code.refresh")
						end, opts)
						map("n", "`", function()
							vscode.action("oil-code.cd")
						end, opts)
					end,
				})
			end
		end,
	},

	{
		"vscode-neovim/vscode-multi-cursor.nvim",
		event = "VeryLazy",
		opts = {},
		config = function()
			local cursors = require("vscode-multi-cursor")
			cursors.setup({ -- Config is optional
				-- Whether to set default mappings
				default_mappings = true,
				-- If set to true, only multiple cursors will be created without multiple selections
				no_selection = true,
			})

			vim.keymap.set({ "n", "x" }, "<C-n>", "mciw*<Cmd>nohl<CR>", { remap = true })

			vim.keymap.set({ "n", "x", "i" }, "<c-m>", function()
				cursors.addSelectionToNextFindMatch()
			end)

			vim.keymap.set({ "n", "x", "i" }, "<cs-l>", function()
				cursors.selectHighlights()
			end)
		end,
	},

	{
		"ggandor/leap.nvim",
		config = function()
			local leap = require("leap")
			leap.add_default_mappings()

			leap.opts.preview_filter = function()
				return false
			end
		end,
	},
	
	{
		"nicwest/vim-camelsnek",
		config = function() end,
	},
	

	{
	"tpope/vim-abolish",
		config = function()
			vim.cmd(":Abolish {stirng,stinrg} string{,}")
			vim.cmd(":Abolish awiat await")
			vim.cmd(":Abolish descriptoin description")
		end,
	}
}
