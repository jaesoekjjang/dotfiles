-- terminal에서 normal mode로 벗어나기: <C-\><C-n>
return {
	{
		"numToStr/FTerm.nvim",
		name = "FTerm.LazyGit.nvim",
		config = function()
			local fterm = require("FTerm")
			local lazygit = fterm:new({
				cmd = "lazygit",
				dimensions = {
					height = 0.9,
					width = 0.9,
				},
			})

			-- -- terminal git
			-- vim.keymap.set("n", "<leader>tg", function()
			-- 	lazygit:toggle()
			-- end, { desc = "Toggle [L]azy[G]it" })
			-- vim.keymap.set("t", "<leader>tg", function()
			-- 	lazygit:toggle()
			-- end, { desc = "Toggle [L]azy[G]it" })
		end,
	},
}
