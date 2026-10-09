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
		if panel.is_hidden then
			require("codediff.ui.history").toggle_visibility(panel)
		end
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

return M
