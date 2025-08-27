local mapKey = require("utils.keyMapper").mapKey

local make_prg_tbl = {
	eslint = {
		prg = "npx eslint . --format unix",
		fmt = "",
	},
	tsc = {
		prg = "tsc --noEmit src/*.{ts,tsx}",
		fmt = "errorformat=%f(%l,%c): error %m",
	},
}

local make_prg_keys = {}
for key, _ in pairs(make_prg_tbl) do
	table.insert(make_prg_keys, key)
end

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
			{ "ThePrimeagen/git-worktree.nvim" },
		},
		config = function()
			local telescope = require("telescope")
			local builtin = require("telescope.builtin")
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")
			local themes = require("telescope.themes")

			local lga_actions = require("telescope-live-grep-args.actions")
			local live_grep_args_shortcuts = require("telescope-live-grep-args.shortcuts")

			mapKey("<leader>ff", function()
				builtin.find_files({
					layout_config = {
						bottom_pane = { height = 0.5 },
					},
					-- attach_mappings = function(file_name, map)
					-- 	-- get directory of current file and open directory with Oil
					-- 	local open_dir_with_oil = function()
					-- 		local oil = require("oil")
					-- 		oil.open(current_dir)
					-- 	end
					--
					-- 	map({ "n", "i" }, "<C-e>", open_dir_with_oil)
					--
					-- 	return true
					-- end,
				})
			end)

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

						map({ "n", "i" }, "<c-d>", delete_buf)

						return true
					end,
				}, {
					sort_lastused = true,
					sort_mru = true,
				})
			end)

			mapKey("<leader>fh", builtin.help_tags)
			mapKey("<leader>fm", builtin.marks)
			mapKey("<leader>fo", builtin.oldfiles)
			mapKey("<leader>sd", builtin.lsp_document_symbols)
			mapKey("<leader>sw", builtin.lsp_workspace_symbols)

			mapKey("<leader>gc", builtin.git_commits)
			mapKey("<leader>gb", builtin.git_branches)
			mapKey("<leader>gs", builtin.git_stash)
			mapKey("<leader>ch", builtin.quickfixhistory)

			mapKey("gd", builtin.lsp_definitions)
			mapKey("gvd", function()
				vim.cmd("vs")
				builtin.lsp_definitions()
			end)
			mapKey("gtd", builtin.lsp_type_definitions)
			mapKey("grr", builtin.lsp_references)
			mapKey("gi", builtin.lsp_implementations)
			mapKey("gs", builtin.spell_suggest)
			mapKey("<leader>dd", function()
				builtin.diagnostics({ bufnr = 0 })
			end)
			mapKey("<leader>dD", builtin.diagnostics)

			mapKey("<leader>gw", "<CMD>lua require('telescope').extensions.git_worktree.git_worktree()<CR>", "n")
			mapKey("<leader>gW", "<CMD>lua require('telescope').extensions.git_worktree.create_git_worktree()<CR>", "n")

			local copy_selection = function()
				local selection = require("telescope.actions.state").get_selected_entry()
				vim.fn.setreg("+", vim.fn.fnamemodify(selection.path, ":."))
			end

			telescope.setup({
				pickers = {
					find_files = {
						-- `hidden = true` will still show the inside of `.git/` as it's not `.gitignore`d.
						find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
						theme = "ivy",
					},
				},
				defaults = themes.get_ivy({
					layout_config = {
						bottom_pane = { height = 0.5 },
					},
					mappings = {
						i = {
							-- ["<C-h>"] = actions.preview_scrolling_left,
							-- ["<C-j>"] = actions.preview_scrolling_down,
							-- ["<C-k>"] = actions.preview_scrolling_up,
							-- ["<C-l>"] = actions.preview_scrolling_right,
							["<C-y>"] = copy_selection,
						},
						n = {
							-- ["<C-h>"] = actions.preview_scrolling_left,
							-- ["<C-j>"] = actions.preview_scrolling_down,
							-- ["<C-k>"] = actions.preview_scrolling_up,
							-- ["<C-l>"] = actions.preview_scrolling_right,
							["<C-y>"] = copy_selection,
						},
					},
				}),
				extensions = {
					["ui-select"] = {
						themes.get_dropdown({}),
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
							make_prg_keys,
						},
						fzf = {
							fuzzy = true, -- false will only do exact matching
							override_generic_sorter = true, -- override the generic sorter
							override_file_sorter = true, -- override the file sorter
							case_mode = "smart_case", -- or "ignore_case" or "respect_case"
						},
					},
				},
			})

			telescope.load_extension("ui-select")
			telescope.load_extension("fzf")
			telescope.load_extension("git_worktree")

			-- custom pickers

			local pickers = require("telescope.pickers")
			local finders = require("telescope.finders")
			local conf = require("telescope.config").values

			local make = function(opts)
				opts = opts or {}
				pickers
					.new(opts, {
						prompt_title = "Make",
						finder = finders.new_table({
							results = make_prg_keys,
						}),
						sorter = conf.generic_sorter(opts),
					})
					:find()
			end

			vim.keymap.set("n", "<leader>mp", function()
				make(require("telescope.themes").get_dropdown({
					attach_mappings = function(prompt_bufnr, map)
						actions.select_default:replace(function()
							actions.close(prompt_bufnr)
							local make_tbl = make_prg_tbl[action_state.get_selected_entry()[1]]

							vim.opt_local.makeprg = make_tbl["prg"]
							vim.opt_local.errorformat = make_tbl["fmt"]
						end)

						return true
					end,
				}))
			end)
		end,
	},
}
