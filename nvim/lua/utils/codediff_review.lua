local M = {}
local tabs = {}
local generation = 0

local function target(cwd)
	local lifecycle = require("codediff.ui.lifecycle")
	local current = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(current)
	if session and session.git_root == cwd then
		return current
	end
	local tab = tabs[cwd]
	if tab and vim.api.nvim_tabpage_is_valid(tab) and lifecycle.get_session(tab) then
		return tab
	end
end

-- Adapter for pinned CodeDiff v4.0.6. Commands create new tabs; replace only
-- the session's panel, retaining the diff windows, layout and quit behavior.
local function show(cwd, tab, config)
	local lifecycle = require("codediff.ui.lifecycle")
	local view = require("codediff.ui.view")
	local session = tab and lifecycle.get_session(tab)
	if not session then
		view.create(config, "")
		tab = vim.api.nvim_get_current_tabpage()
		tabs[cwd] = tab
		if config.panel.name == "history" then
			-- Populate the full recent list in the background. Computing stats
			-- for old commits can be slow in large or cloud-backed repositories.
			require("codediff.ui.refresh").request(tab, { full = true })
		end
		return
	end
	if session.result_win then
		vim.notify("Close the conflict view before switching reviews", vim.log.levels.WARN)
		return
	end
	vim.api.nvim_set_current_tabpage(tab)
	local refresh = require("codediff.ui.refresh")
	refresh.dispose(tab)
	local old = lifecycle.get_panel_view(tab)
	local revision = session.modified_revision
	local selected_path = session.modified and session.modified.relative
	session.panel = nil
	if old then
		lifecycle.detach_keymap_buffer(tab, old.bufnr)
		old.split:hide()
		if vim.api.nvim_buf_is_valid(old.bufnr) then
			vim.api.nvim_buf_delete(old.bufnr, { force = true })
		end
	end
	session.panel = { name = config.panel.name, data = require("codediff.ui.refresh.panel").new(config) }
	session.exit_on_close = session.exit_on_close or config.exit_on_close == true
	local setup = require("codediff.ui.view.panel")
	if config.panel.name == "history" then
		-- Mount without auto-selecting HEAD, so opening history retains the
		-- commit being reviewed when it is present in the recent list.
		local data = session.panel.data
		local commits = data.commits
		data.commits = {}
		setup.setup_history(tab, config, session.original_win, session.modified_win)
		data.commits = commits
		local panel = lifecycle.get_panel_view(tab)
		panel.on_data(data, { list = true })
		local node = panel.tree:get_node("commit:" .. (revision or ""))
		if not node and revision and revision:match("^%x+$") and selected_path and selected_path ~= "" then
			-- The selected commit may arrive only with the full background list.
			-- Keep its diff while that list loads instead of switching to HEAD.
			require("codediff.ui.refresh.panel").set_selection(session.panel, {
				path = selected_path,
				commit_hash = revision,
				git_root = cwd,
			})
		else
			node = node or (commits[1] and panel.tree:get_node("commit:" .. commits[1].hash))
		end
		if node then
			local hash = node.data.hash
			panel.load_commit_files(node, function(err)
				if err or lifecycle.get_panel_view(tab) ~= panel then
					return
				end
				local selected = panel.data.current_selection
				if selected and selected.commit_hash ~= hash then
					return
				end
				local files = panel.data.files[hash] or {}
				local file = files[1]
				for _, candidate in ipairs(files) do
					if candidate.path == selected_path then
						file = candidate
						break
					end
				end
				if file then
					panel.on_file_select(vim.tbl_extend("force", file, { commit_hash = hash, git_root = cwd }))
				end
			end)
		end
	else
		setup.setup_explorer(tab, config, session.original_win, session.modified_win)
	end
	local data = config.panel.data
	local status = data.status_result
	if
		(config.panel.name == "history" and #data.commits == 0)
		or (status and #status.unstaged == 0 and #status.staged == 0 and #(status.conflicts or {}) == 0)
	then
		view.show_welcome(tab)
	end
	refresh.attach(tab)
	-- Re-selecting an unchanged comparison normally skips rendering. A user
	-- may have replaced a diff window's buffer with :edit or a picker, so
	-- explicitly put the selected comparison back into its windows.
	refresh.reopen(tab)
	if config.panel.name == "history" then
		refresh.request(tab, { full = true })
	end
	tabs[cwd] = tab
end

local function request(cwd, exit_on_close, fetch)
	generation = generation + 1
	local token, tab = generation, target(cwd)
	local session = tab and require("codediff.ui.lifecycle").get_session(tab)
	local popup = exit_on_close or (session and session.exit_on_close)
	fetch(function(err, config)
		vim.schedule(function()
			if token ~= generation then
				return
			end
			-- Do not resurrect a review the user closed while Git was loading.
			if
				tab
				and (not vim.api.nvim_tabpage_is_valid(tab) or not require("codediff.ui.lifecycle").get_session(tab))
			then
				return
			end
			if err then
				vim.notify(err, vim.log.levels.ERROR)
				return
			end
			config.git_root = cwd
			config.original = require("codediff.core.path").empty()
			config.modified = require("codediff.core.path").empty()
			config.exit_on_close = popup
			show(cwd, tab, config)
		end)
	end)
end

function M.explorer(cwd, base, commit, exit_on_close)
	request(cwd, exit_on_close, function(done)
		local git = require("codediff.core.git")
		local function loaded(err, status)
			done(err, {
				panel = { name = "explorer", data = { status_result = status } },
				original_revision = base,
				modified_revision = commit,
			})
		end
		if commit then
			git.get_diff_revisions_with_line_stats(base, commit, cwd, loaded)
		else
			git.get_status_with_line_stats(cwd, loaded)
		end
	end)
end

function M.history(cwd, exit_on_close)
	local tab = target(cwd)
	local lifecycle = require("codediff.ui.lifecycle")
	if tab and lifecycle.get_panel_name(tab) == "history" then
		generation = generation + 1
		local session = lifecycle.get_session(tab)
		session.exit_on_close = session.exit_on_close or exit_on_close == true
		vim.api.nvim_set_current_tabpage(tab)
		local panel = lifecycle.get_panel_view(tab)
		if panel.is_hidden or not (panel.winid and vim.api.nvim_win_is_valid(panel.winid)) then
			panel.is_hidden = true
			require("codediff.ui.history").toggle_visibility(panel)
		end
		require("codediff.ui.refresh").reopen(tab)
		vim.api.nvim_set_current_win(panel.winid)
		return
	end
	request(cwd, exit_on_close, function(done)
		-- Show recent history promptly; native refresh expands it to 100.
		require("codediff.core.git").get_commit_list("", cwd, { limit = 10, no_merges = true }, function(err, commits)
			done(err, { panel = { name = "history", data = { commits = commits } } })
		end)
	end)
end

function M.restore()
	local lifecycle = require("codediff.ui.lifecycle")
	local tab = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tab)
	if not session then
		-- Closing a comparison window can tear down the upstream session.
		-- Open a fresh working-tree review when there is nothing left to replay.
		for cwd, review_tab in pairs(tabs) do
			if review_tab == tab then
				return M.explorer(cwd)
			end
		end
		return require("utils.gitdiff").open()
	end
	if session.result_win then
		vim.notify("Conflict view: reopen the conflict from the file list", vim.log.levels.WARN)
		return
	end
	local panel = lifecycle.get_panel_view(tab)
	if panel and (panel.is_hidden or not (panel.winid and vim.api.nvim_win_is_valid(panel.winid))) then
		panel.is_hidden = true
		require("codediff.ui." .. session.panel.name).toggle_visibility(panel)
	end
	require("codediff.ui.refresh").reopen(tab)
end

function M.toggle_panel_position()
	local lifecycle = require("codediff.ui.lifecycle")
	local current = lifecycle.get_session(vim.api.nvim_get_current_tabpage())
	if not current or not current.panel then
		return
	end
	local name = current.panel.name
	local options = require("codediff.config").options[name]
	local position = options.position == "left" and "bottom" or "left"
	options.position = position
	-- The upstream layout manager reads a global option per panel type.
	-- Move every open panel of that type so later resizing stays consistent.
	local sessions = require("codediff.ui.lifecycle.session").get_active_diffs()
	for tab, session in pairs(sessions) do
		local panel = session.panel and session.panel.name == name and lifecycle.get_panel_view(tab)
		if panel and panel.split then
			-- Pinned v4.0.6's Split uses these when a hidden panel is shown again.
			panel.split._position = position == "left" and "left" or "below"
			panel.split._size = position == "left" and options.width or options.height
			if panel.winid and vim.api.nvim_win_is_valid(panel.winid) then
				vim.api.nvim_win_call(panel.winid, function()
					vim.cmd(position == "left" and "wincmd H" or "wincmd J")
					require("codediff.ui.layout").arrange(tab)
				end)
			end
		end
	end
end

local function preview_cursor()
	local lifecycle = require("codediff.ui.lifecycle")
	local tab = vim.api.nvim_get_current_tabpage()
	local session = lifecycle.get_session(tab)
	local panel = session and lifecycle.get_panel_view(tab)
	if not session or not session.dotfiles_auto_preview or not panel
		or vim.api.nvim_get_current_buf() ~= panel.bufnr then
		return
	end
	local node = panel.tree:get_node()
	local file = node and node.data
	if file and file.type == "commit" then
		local hash = file.hash
		panel.load_commit_files(node, function(err)
			-- Git may finish after the cursor moved or preview was disabled.
			if err or not session.dotfiles_auto_preview or lifecycle.get_session(tab) ~= session
				or lifecycle.get_panel_view(tab) ~= panel or vim.api.nvim_get_current_buf() ~= panel.bufnr
			then
				return
			end
			local active = panel.tree:get_node()
			if not active or not active.data or active.data.hash ~= hash then
				return
			end
			local selected = panel.data.current_selection or {}
			local files = panel.data.files[hash] or {}
			local candidate = files[1]
			for _, item in ipairs(files) do
				if item.path == selected.path then candidate = item; break end
			end
			if candidate and (selected.commit_hash ~= hash or selected.path ~= candidate.path) then
				panel.on_file_select(vim.tbl_extend("force", candidate, { commit_hash = hash, git_root = session.git_root }))
			end
		end)
		return
	end
	if not file or file.type == "group" or file.type == "directory" or not file.path then
		return
	end
	local selected = panel.data.current_selection or {}
	if selected.path ~= file.path or selected.group ~= file.group or selected.commit_hash ~= file.commit_hash then
		panel.on_file_select(file)
	end
end

local function toggle_preview()
	local session = require("codediff.ui.lifecycle").get_session(vim.api.nvim_get_current_tabpage())
	if session then
		session.dotfiles_auto_preview = not session.dotfiles_auto_preview
		vim.notify("CodeDiff cursor preview: " .. (session.dotfiles_auto_preview and "ON" or "OFF"))
		preview_cursor()
	end
end

function M.setup_keymaps()
	local group = vim.api.nvim_create_augroup("DotfilesCodeDiffKeys", { clear = true })
	local function bind()
		vim.schedule(function()
			local lifecycle = require("codediff.ui.lifecycle")
			local tab = vim.api.nvim_get_current_tabpage()
			local session = lifecycle.get_session(tab)
			if not session then
				return
			end
			local opts = { desc = "Restore CodeDiff panels" }
			lifecycle.set_tab_keymap(tab, "n", "gR", M.restore, opts)
			lifecycle.set_tab_keymap(tab, "n", "gP", M.toggle_panel_position,
				{ desc = "Move CodeDiff panel left/bottom" })
			local panel = lifecycle.get_panel_view(tab)
			if panel and (session.panel.name == "explorer" or session.panel.name == "history") then
				lifecycle.set_buf_keymap(tab, panel.bufnr, "n", "<C-p>", toggle_preview,
					{ desc = "Toggle CodeDiff cursor preview" }, { suspendable = false })
			end
			-- Keep recovery available after a picker/:edit replaces a diff
			-- window's buffer. The session registry restores prior mappings
			-- on tab leave and disposes them when the review closes.
			local win = vim.api.nvim_get_current_win()
			if win == session.original_win or win == session.modified_win then
				lifecycle.set_buf_keymap(tab, vim.api.nvim_get_current_buf(), "n", "gR", M.restore, opts)
			end
		end)
	end
	vim.api.nvim_create_autocmd("User", { group = group, pattern = "CodeDiffOpen", callback = bind })
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabEnter" }, { group = group, callback = bind })
	vim.api.nvim_create_autocmd("CursorMoved", { group = group, callback = preview_cursor })
end

return M
