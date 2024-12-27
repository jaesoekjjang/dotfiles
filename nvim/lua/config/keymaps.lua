local mapKey = require("utils.keyMapper").mapKey

--save
mapKey("<C-s>", "<cmd>w<cr><esc>", { "i", "x", "n", "s" }, { desc = "Save file" })

-- delete, replace without yank
mapKey("du", '"_d')
mapKey("c", '"_c')

-- pane navigation
mapKey("<C-h>", "<C-w>h")
mapKey("<C-j>", "<C-w>j")
mapKey("<C-k>", "<C-w>k")
mapKey("<C-l>", "<C-w>l")
mapKey("<C-o>", "<C-w>o")

mapKey("<C-,>", "<C-w>1w")
mapKey("<C-.>", "<C-w>9w")

-- pane resize
mapKey("=", [[<cmd>vertical resize +5<cr>]])
mapKey("-", [[<cmd>vertical resize -5<cr>]])
mapKey("+", [[<cmd>horizontal resize +2<cr>]])
mapKey("_", [[<cmd>horizontal resize -2<cr>]])

-- buffer
vim.api.nvim_create_user_command("BD", function()
	vim.cmd("bp") -- 이전 버퍼로 이동
	vim.cmd("bd#") -- 이전 버퍼 제거 닫음
end, {})

-- 이전 버퍼로 이동
mapKey("<BS>", "<C-6>")

-- 현재 버퍼의 path를 클립보드로 복사
vim.api.nvim_create_user_command("CPath", function()
	vim.cmd("let @+=@%")
end, {})

-- 디렉터리를 클립보드로 복사
vim.api.nvim_create_user_command("CParent", function()
	local parent_dir = vim.fn.expand("%:h") -- :help filename_modifier
	vim.fn.setreg("+", parent_dir)
end, {})

-- indent
mapKey("<", "<gv", "v")
mapKey(">", ">gv", "v")

-- blank line
mapKey("<Enter>", "o<ESC>0D")
mapKey("<S-Enter>", "O<ESC>0D")

-- quick fix
mapKey("<leader>co", "<cmd>copen<cr>")
mapKey("cn", "<cmd>cnext<cr>")
mapKey("cp", "<cmd>cprev<cr>")

-- terminal
mapKey("<esc>", [[<C-\><C-n>]], "t")

mapKey("<leader>tn", "<cmd>:term<cr>")
-- force delete
mapKey("<leader>td", function()
	if vim.bo.buftype == "terminal" then
		vim.cmd("bd!")
	end
end, { "n", "t" })
-- short terminal
mapKey("<leader>ts", function()
	vim.cmd.new()
	vim.cmd.term()
	vim.cmd.wincmd("G")
	vim.api.nvim_win_set_height(0, 10)
end)

local function is_lazygit_term(str)
	return str:sub(-7) == "lazygit"
end

-- toggle term
mapKey("<leader>tt", function()
	local cur_buftype = vim.bo.buftype

	local buflist = vim.fn.getbufinfo({ buflisted = 1 })

	table.sort(buflist, function(a, b)
		return a.lastused > b.lastused
	end)

	if cur_buftype == "terminal" then
		for _, buf in ipairs(buflist) do
			local bufnr = buf.bufnr
			local buftype = vim.bo[bufnr].buftype

			if buftype ~= "terminal" then
				vim.cmd("buf" .. buf.bufnr)
				return
			end
		end
	else
		for _, buf in ipairs(buflist) do
			local bufnr = buf.bufnr
			local buftype = vim.bo[bufnr].buftype

			if buftype == "terminal" then
				local bufname = vim.api.nvim_buf_get_name(bufnr)
        print(bufname, is_lazygit_term(bufname))
				if is_lazygit_term(bufname) then
					goto continue
				end

				vim.cmd("buf" .. bufnr)
				return
			end

			::continue::
		end

		vim.cmd("terminal")
	end
end)

vim.api.nvim_create_autocmd("TermOpen", {
	desc = "terminal mode에서 number 제거",
	callback = function()
		vim.opt.number = false
		vim.opt.relativenumber = false
	end,
})

vim.api.nvim_create_autocmd("ExitPre", {
	callback = function()
		local buflist = vim.fn.getbufinfo({ buflisted = 1 })

		for _, buf in ipairs(buflist) do
			local bufnr = buf.bufnr
			local buftype = vim.bo[bufnr].buftype

			if buftype == "terminal" then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
	end,
})

-- lsp
mapKey("gh", vim.lsp.buf.hover)
mapKey("gD", vim.lsp.buf.definition)
mapKey("gq", vim.lsp.buf.code_action)

mapKey("gl", vim.diagnostic.open_float)
mapKey("[d", function()
	vim.diagnostic.goto_prev({
		severity = vim.diagnostic.severity.ERROR,
	})
end)
mapKey("]d", function()
	vim.diagnostic.goto_next({
		serverity = vim.diagnostic.severity.ERROR,
	})
end)
