return {
	"lewis6991/gitsigns.nvim",
	tag = "v2.1.0",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			local function map(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
			end
			local function selection()
				local cursor, anchor = vim.fn.line("."), vim.fn.line("v")
				return { math.min(cursor, anchor), math.max(cursor, anchor) }
			end

			map("n", "]h", function()
				gs.nav_hunk("next", { count = vim.v.count1 })
			end, "Next Git hunk")
			map("n", "[h", function()
				gs.nav_hunk("prev", { count = vim.v.count1 })
			end, "Previous Git hunk")
			map("n", "<leader>hs", gs.stage_hunk, "Stage Git hunk")
			map("x", "<leader>hs", function()
				gs.stage_hunk(selection())
			end, "Stage selected Git lines")
			map("n", "<leader>hr", gs.reset_hunk, "Reset Git hunk")
			map("x", "<leader>hr", function()
				gs.reset_hunk(selection())
			end, "Reset selected Git lines")
			map("n", "<leader>hS", gs.stage_buffer, "Stage Git buffer")
			map("n", "<leader>hu", gs.undo_stage_hunk, "Undo Git hunk stage")
			map("n", "<leader>hp", gs.preview_hunk, "Preview Git hunk")
			map("n", "<leader>hb", gs.blame_line, "Git blame current line")
			map("n", "<leader>hd", gs.diffthis, "Diff current Git buffer")
			map("n", "<leader>hq", gs.setqflist, "Git buffer hunks to quickfix")
			map({ "o", "x" }, "ih", "<cmd>Gitsigns select_hunk<cr>", "Git hunk textobject")
		end,
	},
}
