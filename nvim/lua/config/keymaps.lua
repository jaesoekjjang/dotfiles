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

-- pane resize
mapKey("=", [[<cmd>vertical resize +5<cr>]])
mapKey("-", [[<cmd>vertical resize -5<cr>]])
mapKey("+", [[<cmd>horizontal resize +2<cr>]])
mapKey("_", [[<cmd>horizontal resize -2<cr>]])

-- buffer
vim.api.nvim_create_user_command("Bd", function()
	vim.cmd("bp") -- 이전 버퍼로 이동
	vim.cmd("bd#") -- 이전 버퍼 제거 닫음
end, {})


-- indent
mapKey("<", "<gv", "v")
mapKey(">", ">gv", "v")

-- blank line
mapKey("<Enter>", "o<ESC>0D")
mapKey("<S-Enter>", "O<ESC>0D")
