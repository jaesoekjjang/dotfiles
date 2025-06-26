local mapKey = require("utils.keyMapper").mapKey

local lazygit_bufnr = -1

local toggle_lazygit = function()
	local cur_bufnr = vim.api.nvim_get_current_buf()

	if cur_bufnr == lazygit_bufnr then
		vim.cmd("b#")
	else
		if vim.api.nvim_buf_is_valid(lazygit_bufnr) and vim.fn.bufexists(lazygit_bufnr) then
			vim.api.nvim_set_current_buf(lazygit_bufnr)
		else
			lazygit_bufnr = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(lazygit_bufnr)
      vim.cmd('wincmd o')
			vim.cmd.terminal("lazygit")
		end
	end
end

mapKey("<leader>tg", toggle_lazygit, { "t", "n", "i" })

return {
	{
		"tpope/vim-fugitive",
		config = function()
			mapKey("<space>gg", ":vert G<cr>")
		end,
	},

	{
		"junegunn/gv.vim",
	},

	{
		"idanarye/vim-merginal",
		config = function()
			mapKey("<space>gm", "<cmd>MerginalToggle<cr>")
			vim.g.merginal_windowWidth = math.floor(vim.api.nvim_win_get_width(0) / 2)
		end,
	},

	{ "akinsho/git-conflict.nvim", version = "*", config = true },
}
