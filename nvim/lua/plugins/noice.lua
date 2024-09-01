local mapKey = require("utils.keyMapper").mapKey

return {
	"folke/noice.nvim",
	event = "VeryLazy",
	opts = {
		-- add any options here
	},
	dependencies = {
		-- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
		"MunifTanjim/nui.nvim",
		-- OPTIONAL:
		--   `nvim-notify` is only needed, if you want to use the notification view.
		--   If not available, we use `mini` as the fallback
		"rcarriga/nvim-notify",
	},
	config = function()
		local noice = require("noice")
		noice.setup({
			messages = { enabled = false },
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = false,
					["vim.lsp.util.stylize_markdown"] = false,
					["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
				},
				progress = { enabled = false },
				hover = { enabled = false },
			},
			presets = {
				long_message_to_split = true,
				icn_rename = false,
				bottom_search = false,
				command_palette = true,
				lsp_doc_border = false,
			},
		})

		mapKey("<leader>nl", function()
			noice.cmd("last")
		end)

		mapKey("<leader>nh", function()
			noice.cmd("history")
		end)
	end,
}
