local mapKey = require("utils.keyMapper").mapKey
--save
mapKey("<C-s>", "<cmd>w<cr><esc>", { "i", "x", "n", "s" }, { desc = "Save file" })

-- delete, replace line
mapKey("<S-d>", "dd")
mapKey("<S-c>", "cc")
-- delete, replace without yank
mapKey("du", '"_d')
mapKey("c", '"_c')

-- toggle hls, number
mapKey("<F3>", "<cmd>set hlsearch!<cr>")
mapKey("<F4>", "<cmd>set number! relativenumber!<cr>")
mapKey("<F5>", function()
	local iskeyword = vim.opt.iskeyword:get()
	if vim.tbl_contains(iskeyword, "-") then
		vim.cmd("set iskeyword-=-")
	else
		vim.cmd("set iskeyword+=-")
	end
end)

-- mark
mapKey("'", "`")

-- pane, window
mapKey("<C-h>", "<C-w>h")
mapKey("<C-j>", "<C-w>j")
mapKey("<C-k>", "<C-w>k")
mapKey("<C-l>", "<C-w>l")
mapKey("<C-o>", "<C-w>o")

mapKey("<C-'>", [[<cmd>:vs<cr>]])
mapKey("<C-;>", [[<cmd>:sp<cr>]])

mapKey("<C-,>", "<C-w>1w")
mapKey("<C-.>", "<C-w>9w")

mapKey("<C-q>", "<C-w>q")

-- pane resize
mapKey("=", [[<cmd>vertical resize +5<cr>]])
mapKey("-", [[<cmd>vertical resize -5<cr>]])
mapKey("+", [[<cmd>horizontal resize +2<cr>]])
mapKey("_", [[<cmd>horizontal resize -2<cr>]])

-- buffer ../config/cmd.lua
-- prev buffer
mapKey("<BS>", "<C-6>")
mapKey("<leader>bd", "[[<cmd>bd<cr>]]")
-- change buffer
mapKey("<leader>bc", "[[<cmd>Bd<cr>]]")
-- close all buffers
mapKey("<leader>bx", "[[<cmd>%bd<cr>]]")
mapKey("<leader>bX", "[[<cmd>%bd!<cr>]]")

-- 현재 버퍼를 제외하고 모두 삭제
mapKey("<leader>bo", "[[<cmd>Bdr<cr>]]")

-- indent
mapKey("<", "<gv", "v")
mapKey(">", ">gv", "v")

-- blank line
mapKey("<Enter>", "o<ESC>0D")
mapKey("<S-Enter>", "O<ESC>0D")

-- quick fix
mapKey("<leader>ch", "<cmd>copen<cr>")
mapKey("cn", "<cmd>cnext<cr>")
mapKey("cp", "<cmd>cprev<cr>")

-- visual to bash
mapKey("<leader>r", function()
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local lines = vim.fn.getregion(start_pos, end_pos)
	local script = table.concat(lines, "\n")

	vim.cmd("new")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.bo.filetype = "log"

	local output = vim.fn.system(script)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, "\n"))
end, { "v" })

-- terminal
mapKey("<C-x>", [[<C-\><C-n>]], "t")

mapKey("<leader>tn", "<cmd>:term<cr>")
-- short terminal
mapKey("<leader>ts", function()
	vim.cmd.new()
	vim.cmd.term()
	vim.cmd.wincmd("G")
	vim.api.nvim_win_set_height(0, 10)
end)
mapKey("<leader>td", function()
	if vim.bo.buftype == "terminal" then
		vim.cmd("bd!")
	end
end, { "n", "t" })

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
mapKey("gq", vim.lsp.buf.code_action)
mapKey("grn", vim.lsp.buf.rename)
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

-- autocomplete
mapKey("cl", function()
	vim.cmd("startinsert")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-l>", true, false, true), "n", true)
end)



function hello_world()
end
