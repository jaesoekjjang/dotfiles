return {
	"tpope/vim-abolish",
	config = function()
		vim.cmd(":Abolish {stirng,stinrg} string{,}")
		vim.cmd(":Abolish awiat await")
		vim.cmd(":Abolish descriptoin description")
	end,
}
