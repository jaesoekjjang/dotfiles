-- Keep root discovery out of Vim expression strings: filenames can contain quotes.
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("DotfilesRoot", { clear = true }),
	callback = function(event)
		if vim.g.SessionLoad == 1 or vim.bo[event.buf].buftype ~= "" then
			return
		end
		local name = vim.api.nvim_buf_get_name(event.buf)
		if name == "" then
			return
		end
		local root = vim.fs.root(name, { ".git", ".hg", ".svn" })
		if root and root ~= vim.fn.getcwd() then
			vim.api.nvim_set_current_dir(root)
		end
	end,
})
