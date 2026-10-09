return {
	"sindrets/diffview.nvim",
	enabled = false,
	commit = "4516612fe98ff56ae0415a259ff6361a89419b0a",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "GitReview", "FileDiff" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Repository diff" },
		{
			"<leader>gv",
			function()
				require("utils.gitdiff").review()
			end,
			desc = "Review commit changes",
		},
		{
			"<leader>hD",
			function()
				require("utils.gitdiff").file_diff()
			end,
			desc = "Compare file with revision",
		},
	},
	config = function()
		-- The pinned version starts with `tab split`, briefly duplicating the
		-- current document while its asynchronous diff buffers are loading.
		-- Start with an empty tab so the old document never slides into the layout.
		local View = require("diffview.scene.view").View
		function View:open()
			vim.cmd("tabnew")
			self.tabpage = vim.api.nvim_get_current_tabpage()
			self:init_layout()
			self:post_open()
			DiffviewGlobal.emitter:emit("view_opened", self)
			DiffviewGlobal.emitter:emit("view_enter", self)
		end

		-- The pinned layout blanks both windows and disables diff before loading.
		-- Keep the previous diff visible until the replacement buffers are ready.
		local async = require("diffview.async")
		local Layout = require("diffview.scene.layout").Layout
		local open_files = Layout.open_files
		Layout.open_files = async.void(function(layout)
			if #layout:files() < #layout.windows then
				return async.await(open_files(layout))
			end

			local files = layout:files()
			for _, win in ipairs(layout.windows) do
				if not async.await(win:load_file()) then
					return async.await(open_files(layout))
				end
				-- A newer selection may have replaced this layout while loading.
				for j, current in ipairs(layout.windows) do
					if current.file ~= files[j] then
						return
					end
				end
			end

			async.await(async.scheduler())
			if not layout:is_valid() then
				return
			end
			for i, win in ipairs(layout.windows) do
				if win.file ~= files[i] then
					return
				end
			end
			local lazyredraw = vim.o.lazyredraw
			vim.o.lazyredraw = true
			local ok, err = xpcall(function()
				vim.cmd("diffoff!")
				-- Install every buffer before enabling diff on either side. Otherwise
				-- Neovim briefly compares the new left file with the old right file.
				for _, win in ipairs(layout.windows) do
					vim.api.nvim_win_set_buf(win.id, win.file.bufnr)
				end
				for _, win in ipairs(layout.windows) do
					async.await(win:open_file())
				end
				vim.cmd("diffupdate")
				layout:sync_scroll()
				layout.emitter:emit("files_opened")
			end, debug.traceback)
			vim.o.lazyredraw = lazyredraw
			if not ok then
				error(err)
			end
		end)

		local close = { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } }
		require("diffview").setup({
			keymaps = { view = { close }, file_panel = { close }, file_history_panel = { close } },
		})
		vim.api.nvim_create_user_command("GitReview", function(opts)
			require("utils.gitdiff").review(opts.args)
		end, { nargs = "?", desc = "Review one commit, or choose it from a picker" })
		vim.api.nvim_create_user_command("FileDiff", function(opts)
			require("utils.gitdiff").file_diff(opts.args)
		end, { nargs = "?", desc = "Compare current file with a revision, or choose it from a picker" })
	end,
}
