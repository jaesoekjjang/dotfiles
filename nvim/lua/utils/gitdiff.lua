local M = {}

local function git(cwd, args, stdin)
	local command = { "git" }
	vim.list_extend(command, args)
	return vim.system(command, { cwd = cwd, text = true, stdin = stdin }):wait()
end

local function context()
	local lifecycle = package.loaded["codediff.ui.lifecycle"]
	local session = lifecycle and lifecycle.get_session(vim.api.nvim_get_current_tabpage())
	if session and session.git_root then
		return session.git_root, vim.api.nvim_buf_get_name(0), session.exit_on_close
	end
	local file = vim.api.nvim_buf_get_name(0)
	if vim.fn.exists("*FugitiveReal") == 1 then
		file = vim.fn.FugitiveReal(file)
	end
	local cwd = vim.fs.root(file, ".git") or vim.fn.getcwd()
	local root = git(cwd, { "rev-parse", "--show-toplevel" })
	if root.code ~= 0 then
		vim.notify("Not in a Git repository", vim.log.levels.WARN)
		return
	end
	return vim.trim(root.stdout), file
end

local function resolve(cwd, revision)
	local result = git(cwd, { "rev-parse", "--verify", "--end-of-options", revision .. "^{commit}" })
	if result.code ~= 0 then
		vim.notify("Invalid Git revision: " .. revision, vim.log.levels.WARN)
		return
	end
	return vim.trim(result.stdout)
end

local function review(cwd, revision, exit_on_close)
	local commit = resolve(cwd, revision)
	if not commit then
		return
	end
	-- Compare merges with their first parent and root commits with the empty tree.
	local parent = git(cwd, { "rev-parse", "--verify", commit .. "^" })
	local base = parent.code == 0 and vim.trim(parent.stdout)
		or vim.trim(git(cwd, { "hash-object", "-t", "tree", "--stdin" }, "").stdout)
	require("utils.codediff_review").explorer(cwd, base, commit, exit_on_close)
end

function M.open(exit_on_close)
	local cwd = context()
	if not cwd then
		return
	end
	local status = git(cwd, { "status", "--porcelain", "--untracked-files=normal" })
	if status.code ~= 0 then
		vim.notify(vim.trim(status.stderr), vim.log.levels.ERROR)
		return
	end
	if status.stdout ~= "" then
		require("utils.codediff_review").explorer(cwd, nil, nil, exit_on_close)
		return
	end
	local head = git(cwd, { "log", "-1", "--format=%h %s" })
	if head.code ~= 0 then
		vim.notify("No changes or commits to show", vim.log.levels.INFO)
		return
	end
	vim.notify("No uncommitted changes · showing HEAD: " .. vim.trim(head.stdout), vim.log.levels.INFO)
	review(cwd, "HEAD", exit_on_close)
end

function M.history(exit_on_close)
	local cwd = context()
	if cwd then
		require("utils.codediff_review").history(cwd, exit_on_close)
	end
end

local function choose(cwd, file, callback)
	local win = vim.api.nvim_get_current_win()
	local function apply(revision)
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
			callback(revision)
		end
	end
	local function input(picker)
		picker:close()
		vim.ui.input({ prompt = "Git hash / branch / tag: " }, function(revision)
			if revision and vim.trim(revision) ~= "" then
				apply(vim.trim(revision))
			end
		end)
	end
	local opts = {
		cwd = cwd,
		title = file and "Compare file with commit (Ctrl-r: enter revision)"
			or "Review commit (Ctrl-r: enter revision)",
		confirm = function(picker, item)
			picker:close()
			if item and item.commit then
				apply(item.commit)
			end
		end,
		actions = { revision_input = input },
		win = {
			input = { keys = { ["<C-r>"] = { "revision_input", mode = { "n", "i" } } } },
			list = { keys = { ["<C-r>"] = "revision_input" } },
		},
	}
	if file then
		opts.current_file = true
	end
	return Snacks.picker.git_log(opts)
end

function M.review(revision)
	local cwd, _, exit_on_close = context()
	if cwd then
		if revision and revision ~= "" then
			review(cwd, revision, exit_on_close)
		else
			return choose(cwd, false, function(value)
				review(cwd, value, exit_on_close)
			end)
		end
	end
end

function M.file_diff(revision)
	local cwd, file = context()
	if not cwd then
		return
	end
	if vim.bo.buftype ~= "" or file == "" then
		vim.notify("Open a file before comparing revisions", vim.log.levels.WARN)
		return
	end
	local function compare(value)
		local commit = resolve(cwd, value)
		if commit then
			vim.cmd("Gvdiffsplit " .. commit)
		end
	end
	if revision and revision ~= "" then
		compare(revision)
	else
		return choose(cwd, file, compare)
	end
end

return M
