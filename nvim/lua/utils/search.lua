local M = {}

function M.directory(folder)
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" or vim.bo.buftype ~= "" then
		return vim.fn.getcwd()
	end
	if folder then
		return vim.fs.dirname(name)
	end
	return vim.fs.root(name, { ".git", ".hg", ".svn" }) or vim.fn.getcwd()
end

local function options(label, folder)
	local cwd = M.directory(folder)
	return {
		cwd = cwd,
		title = label .. " · " .. vim.fn.fnamemodify(cwd, ":~"),
		hidden = true,
		ignored = false,
	}
end

function M.files(folder)
	return Snacks.picker.files(options("Files", folder))
end

function M.smart()
	local opts = options("Smart files", false)
	opts.filter = { cwd = true }
	return Snacks.picker.smart(opts)
end

function M.grep_buffers()
	return Snacks.picker.grep_buffers({ title = "Grep open files", regex = true })
end

function M.grep(folder, word)
	local opts = options("Grep", folder)
	if word or vim.fn.mode():match("[vV\22]") then
		opts.live = true
		return Snacks.picker.grep_word(opts)
	end
	opts.regex = true
	return Snacks.picker.grep(opts)
end

function M.recent(all)
	local opts = options("Recent", false)
	opts.filter = { cwd = not all }
	if all then
		opts.title = "Recent · All projects"
	end
	return Snacks.picker.recent(opts)
end

return M
