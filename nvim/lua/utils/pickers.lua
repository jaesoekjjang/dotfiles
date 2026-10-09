local M = {}

local function git(args, cwd)
	local command = { "git" }
	vim.list_extend(command, args)
	return vim.system(command, { cwd = cwd, text = true }):wait()
end

local function git_error(result)
	vim.notify(vim.trim(result.stderr or result.stdout or "Git command failed"), vim.log.levels.ERROR)
end

function M.quickfix_history()
	local items = {}
	for nr = vim.fn.getqflist({ nr = "$" }).nr, 1, -1 do
		local list = vim.fn.getqflist({ nr = nr, all = true })
		local lines = {}
		for _, entry in ipairs(list.items) do
			local file = entry.bufnr > 0 and vim.api.nvim_buf_get_name(entry.bufnr) or ""
			table.insert(lines, ("%s:%d: %s"):format(file, entry.lnum, entry.text))
		end
		table.insert(items, {
			text = ("%d: %s (%d items)"):format(nr, list.title, list.size),
			id = list.id,
			preview = { text = table.concat(lines, "\n"), ft = "text" },
		})
	end
	return Snacks.picker.pick({
		title = "Quickfix history",
		items = items,
		format = "text",
		preview = "preview",
		confirm = function(picker, item)
			picker:close()
			if item then
				local nr = vim.fn.getqflist({ id = item.id, nr = 0 }).nr
				if nr > 0 then
					vim.cmd("chistory " .. nr)
					vim.cmd.copen()
				end
			end
		end,
	})
end

function M.switch_worktree(path)
	local previous = git({ "rev-parse", "--show-toplevel" })
	local file = vim.api.nvim_buf_get_name(0)
	local modified = vim.bo.modified
	local relative
	if previous.code == 0 then
		local root = vim.trim(previous.stdout) .. "/"
		if file:sub(1, #root) == root then
			relative = file:sub(#root + 1)
		end
	end
	vim.api.nvim_set_current_dir(path)
	if relative and not modified then
		local target = vim.fs.joinpath(path, relative)
		if vim.fn.filereadable(target) == 1 then
			vim.cmd.edit(vim.fn.fnameescape(target))
		end
	end
	-- fff also follows DirChanged; the next search uses the selected worktree.
	vim.notify("Worktree: " .. path)
end

function M.worktrees()
	local result = git({ "worktree", "list", "--porcelain", "-z" })
	if result.code ~= 0 then
		git_error(result)
		return
	end
	local items, current = {}, nil
	for field in result.stdout:gmatch("([^%z]+)%z") do
		if field:sub(1, 9) == "worktree " then
			current = { file = field:sub(10), branch = "detached" }
			table.insert(items, current)
		elseif current and field:sub(1, 7) == "branch " then
			current.branch = field:sub(8):gsub("^refs/heads/", "")
		elseif current and field == "bare" then
			current.bare = true
		end
	end
	for _, item in ipairs(items) do
		item.text = item.file .. " [" .. (item.bare and "bare" or item.branch) .. "]"
	end
	return Snacks.picker.pick({
		title = "Git worktrees",
		items = items,
		format = "text",
		preview = false,
		confirm = function(picker, item)
			if item and not item.bare then
				picker:close()
				M.switch_worktree(item.file)
			end
		end,
	})
end

function M.create_worktree()
	local root = git({ "rev-parse", "--show-toplevel" })
	if root.code ~= 0 then
		git_error(root)
		return
	end
	local cwd = vim.trim(root.stdout)
	vim.ui.input({ prompt = "Worktree branch (existing or new): " }, function(branch)
		if not branch or branch == "" then
			return
		end
		if git({ "check-ref-format", "--branch", branch }, cwd).code ~= 0 then
			vim.notify("Invalid branch name", vim.log.levels.ERROR)
			return
		end
		vim.ui.input({
			prompt = "Worktree path: ",
			default = vim.fs.joinpath(vim.fs.dirname(cwd), vim.fs.basename(cwd) .. "__worktrees", branch),
			completion = "dir",
		}, function(path)
			if not path or path == "" then
				return
			end
			path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
			local args = { "git", "worktree", "add" }
			local exists = git({ "show-ref", "--verify", "--quiet", "refs/heads/" .. branch }, cwd)
			if exists.code == 0 then
				vim.list_extend(args, { "--", path, branch })
			elseif exists.code == 1 then
				vim.list_extend(args, { "-b", branch, "--", path })
			else
				git_error(exists)
				return
			end
			vim.system(
				args,
				{ cwd = cwd, text = true },
				vim.schedule_wrap(function(result)
					if result.code == 0 then
						M.switch_worktree(path)
					else
						git_error(result)
					end
				end)
			)
		end)
	end)
end

function M.make_program()
	local programs = {
		{ name = "eslint", prg = "npx eslint . --format unix", fmt = "" },
		{ name = "tsc", prg = "tsc --noEmit", fmt = "%f(%l,%c): error %m" },
	}
	vim.ui.select(programs, {
		prompt = "Make program",
		format_item = function(item)
			return item.name
		end,
	}, function(item)
		if item then
			vim.opt_local.makeprg = item.prg
			vim.opt_local.errorformat = item.fmt
		end
	end)
end

return M
