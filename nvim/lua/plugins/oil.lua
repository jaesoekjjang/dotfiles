return {
	"stevearc/oil.nvim",
	opts = {},
	-- Optional dependencies
	dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
	config = function()
		local oil = require("oil")
		local detail = false

		oil.setup({
			view_options = {
				show_hidden = true,
			},
			delete_to_trash = true,
			skip_confirm_for_simple_edits = true,
			cleanup_delay_ms = 0,
			keymaps = {
				["g?"] = "actions.show_help",
				["<CR>"] = "actions.select",
				["<space>"] = "actions.select",
				["<C-s>"] = false,
				["<C-h>"] = false,
				["<C-l>"] = false,
				["<C-v>"] = {
					"actions.select",
					opts = { vertical = true },
					desc = "Open the entry in a vertical split",
				},
				["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
				["<C-p>"] = "actions.preview",
				["<C-c>"] = "actions.close",
				["-"] = "actions.parent",
				["<esc>"] = "actions.parent",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
				["gd"] = {
					desc = "Toggle file detail view",
					callback = function()
						detail = not detail
						if detail then
							require("oil").set_columns({
								"icon",
								{ "permissions", highlight = "Special" },
								{ "size", highlight = "Type" },
								{ "mtime", highlight = "Error", format = "%Y-%m-%d %H:%M" },
							})
						else
							require("oil").set_columns({ "icon" })
						end
					end,
				},
				["gs"] = "actions.change_sort",
				["gx"] = "actions.open_external",
				["g."] = "actions.toggle_hidden",
				["g\\"] = "actions.toggle_trash",
			},
		})

		vim.keymap.set("n", "<leader>ee", "<CMD>Oil<Cr>", { desc = "Open parent directory" })
	end,
}
--float
