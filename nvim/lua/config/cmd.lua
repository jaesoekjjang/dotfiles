-- 현재 버퍼 닫고 이전 버퍼로 이동
vim.api.nvim_create_user_command("Bd", function()
	vim.cmd("bp")
	vim.cmd("bd#")
end, {})

-- 현재 버퍼를 제외한 모든 버퍼 제거
vim.api.nvim_create_user_command("Bdr", function()
	local current_buf = vim.api.nvim_get_current_buf()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end, {})

local function parse_flag(flag)
	if flag:sub(1, 1) == "-" then
		local result = ":" .. flag:sub(2):gsub(".", function(c)
			return c .. ":"
		end)
		return result:sub(1, -2)
	else
		return ""
	end
end

vim.api.nvim_create_user_command("CPath", function(o)
	local flags = o.args
	local modifier = vim.fn.expand("%" .. parse_flag(flags))

	vim.fn.setreg("+", modifier)
end, {
	nargs = "?",
})

vim.api.nvim_create_user_command("CPathLine", function()
	local abs = vim.fn.expand("%:p")
	local root = vim.fn.getcwd() .. "/"
	local path = abs:sub(#root + 1)
	local line = vim.fn.line(".")
	vim.fn.setreg("+", path .. ":" .. line)
end, {})

vim.api.nvim_create_user_command("CParent", function(o)
	local flags = o.args
	local modifier = vim.fn.expand("%:h" .. parse_flag(flags))

	vim.fn.setreg("+", modifier)
end, {
	nargs = "?",
})

-- 모든 북마크 제거
vim.api.nvim_create_user_command("Mda", function()
	vim.cmd("delm! | delm A-Z0-9")
end, {})
