local mapKey = require("utils.keyMapper").mapKey

return {
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-ui-select.nvim",
			{
				"nvim-telescope/telescope-live-grep-args.nvim",
				version = "^1.0.0",
			},
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		config = function()
			-- keymaps
			local builtin = require("telescope.builtin")
			local telescope = require("telescope")
			local action_state = require("telescope.actions.state")

			local lga_actions = require("telescope-live-grep-args.actions")
			local live_grep_args_shortcuts = require("telescope-live-grep-args.shortcuts")

			mapKey("<leader>ff", builtin.find_files)

			mapKey("<leader>fg", telescope.extensions.live_grep_args.live_grep_args, "n")
			mapKey("<leader>fg", live_grep_args_shortcuts.grep_visual_selection, "v")

			mapKey("<leader>fb", function()
				builtin.buffers({
					attach_mappings = function(prompt_bufnr, map)
						local delete_buf = function()
							local current_picker = action_state.get_current_picker(prompt_bufnr)
							current_picker:delete_selection(function(selection)
								vim.api.nvim_buf_delete(selection.bufnr, { force = true })
							end)
						end

						map({"n", "i"}, "<c-d>", delete_buf)

						return true
					end,
				}, {
					sort_lastused = true,
					sort_mru = true,
					theme = "dropdown",
				})
			end)
			-- mapKey("<leader>fb", builtin.buffers)
			mapKey("<leader>fh", builtin.help_tags)
			mapKey("<leader>fo", builtin.oldfiles)
			mapKey("<leader>fm", builtin.marks)

			telescope.setup({
				pickers = {
					find_files = {
						-- `hidden = true` will still show the inside of `.git/` as it's not `.gitignore`d.
						find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
					},
				},
				defaults = {
					path_display = nil,
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
					live_grep_args = {
						auto_quoting = true, -- enable/disable auto-quoting
						-- define mappings, e.g.
						-- https://github.com/JoosepAlviste/dotfiles/blob/master/config/nvim/lua/j/telescope_custom_pickers.lua
						mappings = { -- extend mappings
							i = {
								["<C-k>"] = lga_actions.quote_prompt(),
								["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
								["<C-d>"] = require("telescope.actions").delete_buffer,
							},
							n = {
								["<C-d>"] = require("telescope.actions").delete_buffer,
							},
						},
					},
					fzf = {
						fuzzy = true, -- false will only do exact matching
						override_generic_sorter = true, -- override the generic sorter
						override_file_sorter = true, -- override the file sorter
						case_mode = "smart_case", -- or "ignore_case" or "respect_case"
					},
				},
			})

			telescope.load_extension("ui-select")
			telescope.load_extension("live_grep_args")
			telescope.load_extension("fzf")
		end,
	},
}
