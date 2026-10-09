local function copy_path()
	-- fff v0.11 exposes its current selection through the picker state.
	local state = require("fff.picker_ui.picker_ui").state
	local item = state.filtered_items[state.cursor]
	if item then
		local path = vim.fs.joinpath(state.config.base_path, item.relative_path)
		vim.fn.setreg("+", vim.fn.fnamemodify(path, ":."))
		vim.notify("경로 복사됨", vim.log.levels.INFO, { title = "Clipboard", timeout = 800 })
	end
end

return {
	"dmtrKovalenko/fff",
	tag = "v0.11.0",
	lazy = false,
	build = function()
		require("fff.download").download_or_build_binary()
	end,
	opts = {
		lazy_sync = true,
		prompt_vim_mode = true,
		layout = {
			anchor = "bottom",
			height = 0.5,
			width = 1,
			prompt_position = "top",
			preview_position = "right",
		},
		grep = {
			modes = { "fuzzy", "plain", "regex" },
			enable_filename_constraint = false,
		},
		mappings = {
			i = { ["<C-o>"] = copy_path },
			n = { ["<C-o>"] = copy_path },
		},
	},
	keys = {
		{
			"<leader>fr",
			function()
				require("fff").resume()
			end,
			desc = "Resume fff search",
		},
		{
			"<leader>ff",
			function()
				require("fff").find_files()
			end,
			desc = "Find files",
		},
		{
			"<leader>fg",
			function()
				require("fff").live_grep()
			end,
			desc = "Search file contents",
		},
		{
			"<leader>fg",
			function()
				require("fff").live_grep_under_cursor()
			end,
			mode = "x",
			desc = "Search selection",
		},
	},
}
