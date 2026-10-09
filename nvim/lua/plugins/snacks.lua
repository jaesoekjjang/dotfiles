return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		-- your configuration comes here
		-- or leave it empty to use the default settings
		-- refer to the configuration section below
		bigfile = { enabled = true },
		dashboard = { enabled = false },
		explorer = { enabled = false },
		indent = { enabled = false },
		input = { enabled = false },
		picker = {
			enabled = true,
			ui_select = true,
			layout = { preset = "ivy", layout = { height = 0.5 } },
			actions = {
				copy_path = function(_, item)
					local value, kind
					if item and item.commit then
						value, kind = item.commit, "Hash"
					elseif item and item.file then
						value, kind = vim.fn.fnamemodify(item.file, ":."), "경로"
					end
					if value then
						vim.fn.setreg("+", value)
						vim.notify(kind .. " 복사됨", vim.log.levels.INFO, { title = "Clipboard", timeout = 800 })
					end
				end,
			},
			win = {
				input = { keys = { ["<C-o>"] = { "copy_path", mode = { "n", "i" } } } },
				list = { keys = { ["<C-o>"] = "copy_path" } },
			},
			sources = {
				lsp_symbols = { filter = { default = true, lua = true } },
				lsp_workspace_symbols = { filter = { default = true, lua = true } },
				buffers = {
					sort_lastused = true,
					win = { input = { keys = { ["<C-d>"] = { "bufdelete", mode = { "n", "i" } } } } },
				},
			},
		},
		-- Noice/nvim-notify owns notifications.
		notifier = { enabled = false },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = false },
		win = {
			width = 1,
			height = 1,
		},
	},
	keys = {
		{
			"<leader>aw",
			function()
				Snacks.terminal({ "workspace" }, {
					cwd = vim.fn.getcwd(),
					win = { position = "float", width = 0.9, height = 0.85 },
				})
			end,
			desc = "AI workspace menu",
		},
		{
			"<leader>fG",
			function()
				Snacks.picker.grep()
			end,
			desc = "Search with ripgrep options",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>fh",
			function()
				Snacks.picker.help()
			end,
			desc = "Help tags",
		},
		{
			"<leader>fm",
			function()
				Snacks.picker.marks()
			end,
			desc = "Marks",
		},
		{
			"<leader>fo",
			function()
				Snacks.picker.recent()
			end,
			desc = "Recent files",
		},
		{
			"<leader>sd",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "Document symbols",
		},
		{
			"<leader>sw",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "Workspace symbols",
		},
		{
			"<leader>gc",
			function()
				Snacks.picker.git_log({
					confirm = function(picker, item)
						picker:close()
						if item and item.commit then
							vim.cmd("Gedit " .. item.commit)
						end
					end,
				})
			end,
			desc = "Git commits",
		},
		{
			"<leader>gb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git branches",
		},
		{
			"<leader>gs",
			function()
				Snacks.picker.git_stash()
			end,
			desc = "Git stash",
		},
		{
			"<leader>qh",
			function()
				require("utils.pickers").quickfix_history()
			end,
			desc = "Quickfix history",
		},
		{
			"<leader>ql",
			function()
				Snacks.picker.qflist()
			end,
			desc = "Search current quickfix list",
		},
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "Definition",
		},
		{
			"gvd",
			function()
				Snacks.picker.lsp_definitions({ confirm = "edit_vsplit" })
			end,
			desc = "Definition in vertical split",
		},
		{
			"gtd",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "Type definition",
		},
		{
			"grr",
			function()
				Snacks.picker.lsp_references()
			end,
			desc = "References",
		},
		{
			"gi",
			function()
				Snacks.picker.lsp_implementations()
			end,
			desc = "Implementation",
		},
		{
			"gs",
			function()
				Snacks.picker.spelling()
			end,
			desc = "Spelling suggestions",
		},
		{
			"<leader>dd",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Buffer diagnostics",
		},
		{
			"<leader>dD",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>gw",
			function()
				require("utils.pickers").worktrees()
			end,
			desc = "Switch worktree",
		},
		{
			"<leader>gW",
			function()
				require("utils.pickers").create_worktree()
			end,
			desc = "Create worktree",
		},
		{
			"<leader>u",
			function()
				Snacks.picker.undo()
			end,
			desc = "Undo history",
		},
		{
			"<leader>mp",
			function()
				require("utils.pickers").make_program()
			end,
			desc = "Select make program",
		},
	},
	config = function(_, opts)
		require("snacks").setup(opts)
	end,
}
