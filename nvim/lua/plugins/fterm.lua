-- terminal에서 normal mode로 벗어나기: <C-\><C-n>
return {
	{
		"numToStr/FTerm.nvim",
		name = "FTerm.scratch.nvim",
		config = function()
			local fterm = require("FTerm")

			-- npm run dev 명령어 등록 :NpmRunDev
			local npm_run_dev = fterm:new({ cmd = {
				"npm",
				"run",
				"dev",
			} })

			local function toggle()
				npm_run_dev:toggle()
			end

			vim.api.nvim_create_user_command("NpmRunDev", toggle, { bang = true })
			-- terminal node dev
			vim.keymap.set("n", "<leader>tnd", toggle)
			vim.keymap.set("t", "<leader>tnd", toggle)

			-- REPL: 코드 실행
			local runners = { javascript = "node" }

			vim.keymap.set("n", "<leader>t<Enter>", function()
				local buf = vim.api.nvim_buf_get_name(0)
				local ftype = vim.filetype.match({ filename = buf })
				local exec = runners[ftype]
				if exec ~= nil then
					require("FTerm").scratch({ cmd = { exec, buf } })
				end
			end)
		end,
	},
	{
		"numToStr/FTerm.nvim",
		name = "FTerm.DefaultTerminal.nvim",
		config = function()
			local fterm = require("FTerm")
			vim.keymap.set("n", "<leader>tt", function()
				fterm:toggle()
			end, { desc = "[T]oggle [T]terminal" })
			vim.keymap.set("t", "<leader>tt", function()
				fterm:toggle()
			end, { desc = "[T]oggle [T]erminal" })
		end,
	},
	{
		"numToStr/FTerm.nvim",
		name = "FTerm.LazyGit.nvim",
		config = function()
			local fterm = require("FTerm")
			local lazygit = fterm:new({
				cmd = "lazygit",
			})

			-- terminal git
			vim.keymap.set("n", "<leader>tg", function()
				lazygit:toggle()
			end, { desc = "Toggle [L]azy[G]it" })
			vim.keymap.set("t", "<leader>tg", function()
				lazygit:toggle()
			end, { desc = "Toggle [L]azy[G]it" })
		end,
	},
}
