return {
	-- Already used by render-markdown; enable only the IdeaVim-inspired features.
	"echasnovski/mini.nvim",
	event = "VeryLazy",
	config = function()
		local ai = require("mini.ai")
		ai.setup({
			mappings = {
				around = "",
				inside = "",
				around_next = "",
				inside_next = "",
				around_last = "",
				inside_last = "",
				goto_left = "",
				goto_right = "",
			},
		})
		for _, mode in ipairs({ "o", "x" }) do
			for _, kind in ipairs({ "i", "a" }) do
				vim.keymap.set(mode, kind .. "a", function()
					ai.select_textobject(kind, "a", {
						operator_pending = mode == "o",
						n_times = vim.v.count1,
					})
				end, { desc = kind == "i" and "Inside argument" or "Around argument" })
			end
		end

		local operators = require("mini.operators")
		operators.setup({
			evaluate = { prefix = "" },
			exchange = { prefix = "" },
			multiply = { prefix = "" },
			replace = { prefix = "" },
			sort = { prefix = "" },
		})
		operators.make_mappings("replace", { textobject = "P", line = "Pr", selection = "P" })
	end,
}
