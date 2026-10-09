local M = {}

local config = {
	host = "127.0.0.1",
	port = 8080,
	watcher_version = "2.1.14",
}

local state = {
	job_id = nil,
	phase = nil,
	file = nil,
}
local stopped_jobs = {}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Swagger preview" })
end

local function preview_url()
	return ("http://%s:%d"):format(config.host, config.port)
end

local function reset_job(id)
	if state.job_id == id then
		state.job_id = nil
		state.phase = nil
		state.file = nil
	end
end

local function is_running()
	if not state.job_id then
		return false
	end

	if vim.fn.jobwait({ state.job_id }, 0)[1] == -1 then
		return true
	end

	reset_job(state.job_id)
	return false
end

local function stop(silent)
	if not is_running() then
		if not silent then
			notify("No preview is running", vim.log.levels.WARN)
		end
		return true
	end

	local active_job = state.job_id
	stopped_jobs[active_job] = true

	if vim.fn.jobstop(active_job) == 0 then
		stopped_jobs[active_job] = nil
		notify("Failed to stop the preview", vim.log.levels.ERROR)
		return false
	end

	if vim.fn.jobwait({ active_job }, 1000)[1] == -1 then
		if not silent then
			notify("Preview is still stopping", vim.log.levels.WARN)
		end
		return false
	end

	reset_job(active_job)
	if not silent then
		notify("Preview stopped")
	end
	return true
end

local function collect_output(output, lines)
	for _, line in ipairs(lines or {}) do
		if line ~= "" then
			table.insert(output, line)
			if #output > 20 then
				table.remove(output, 1)
			end
		end
	end
end

local function output_details(output)
	return #output > 0 and ("\n" .. table.concat(output, "\n")) or ""
end

local function find_cached_watcher()
	local npm_cache = vim.env.NPM_CONFIG_CACHE or vim.env.npm_config_cache or vim.fn.expand("~/.npm")
	local pattern = npm_cache .. "/_npx/*/node_modules/swagger-ui-watcher/package.json"
	local newest

	for _, package_json in ipairs(vim.fn.glob(pattern, false, true)) do
		local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json), "\n"))
		if ok and package.version == config.watcher_version then
			local node_modules = vim.fn.fnamemodify(package_json, ":h:h")
			local executable = node_modules .. "/.bin/swagger-ui-watcher"
			local stat = vim.uv.fs_stat(executable)
			if stat and vim.fn.executable(executable) == 1 then
				local modified = stat.mtime.sec
				if not newest or modified > newest.modified then
					newest = { executable = executable, modified = modified }
				end
			end
		end
	end

	return newest and newest.executable or nil
end

local function start_server(executable, file)
	local output = {}
	local browser_opened = false
	local url = preview_url()

	local function collect(_, lines)
		collect_output(output, lines)
		for _, line in ipairs(lines or {}) do
			if not browser_opened and line:find("Listening on ", 1, true) then
				browser_opened = true
				state.phase = "running"
				vim.schedule(function()
					vim.ui.open(url)
					notify("Preview ready at " .. url)
				end)
			end
		end
	end

	local started_job = vim.fn.jobstart({
		executable,
		file,
		"--host",
		config.host,
		"--port",
		tostring(config.port),
		"--no-open",
	}, {
		cwd = vim.fn.fnamemodify(file, ":h"),
		on_stdout = collect,
		on_stderr = collect,
		on_exit = function(id, exit_code)
			local was_stopped = stopped_jobs[id]
			stopped_jobs[id] = nil
			reset_job(id)

			if not was_stopped then
				vim.schedule(function()
					notify(
						("Preview failed with exit code %d%s"):format(exit_code, output_details(output)),
						vim.log.levels.ERROR
					)
				end)
			end
		end,
	})

	if started_job <= 0 then
		notify("Failed to start swagger-ui-watcher", vim.log.levels.ERROR)
		return
	end

	state.job_id = started_job
	state.phase = "starting"
	state.file = file
	if vim.bo.modified then
		notify("Starting preview; save the buffer to include your latest changes", vim.log.levels.WARN)
	else
		notify("Starting preview at " .. url)
	end
end

local function install_watcher(file)
	local output = {}
	local package = "swagger-ui-watcher@" .. config.watcher_version

	local started_job = vim.fn.jobstart({ "npx", "--yes", package, "--help" }, {
		cwd = vim.fn.fnamemodify(file, ":h"),
		on_stdout = function(_, lines)
			collect_output(output, lines)
		end,
		on_stderr = function(_, lines)
			collect_output(output, lines)
		end,
		on_exit = function(id, exit_code)
			local was_stopped = stopped_jobs[id]
			stopped_jobs[id] = nil
			reset_job(id)
			if was_stopped then
				return
			end

			vim.schedule(function()
				local executable = find_cached_watcher()
				if exit_code ~= 0 or not executable then
					notify(
						("Failed to prepare swagger-ui-watcher%s"):format(output_details(output)),
						vim.log.levels.ERROR
					)
					return
				end
				start_server(executable, file)
			end)
		end,
	})

	if started_job <= 0 then
		notify("Failed to start npx", vim.log.levels.ERROR)
		return
	end

	state.job_id = started_job
	state.phase = "installing"
	state.file = file
	notify("Preparing swagger-ui-watcher in the npx cache; the first run may take a while")
end

function M.start()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" or vim.fn.filereadable(file) ~= 1 then
		notify("Save the current buffer before starting a preview", vim.log.levels.ERROR)
		return
	end

	if is_running() then
		if state.file == file then
			if state.phase == "running" then
				vim.ui.open(preview_url())
				notify("Preview is already running at " .. preview_url())
			else
				notify("Preview is already " .. state.phase)
			end
			return
		end

		if not stop(true) then
			notify("Wait for the existing preview to stop, then try again", vim.log.levels.WARN)
			return
		end
	end

	local executable = find_cached_watcher()
	if executable then
		start_server(executable, file)
	else
		install_watcher(file)
	end
end

function M.stop()
	stop(false)
end

function M.toggle()
	if is_running() then
		stop(false)
	else
		M.start()
	end
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	vim.api.nvim_create_user_command("SwaggerPreview", M.start, { desc = "Preview the current OpenAPI document" })
	vim.api.nvim_create_user_command("SwaggerPreviewStop", M.stop, { desc = "Stop the OpenAPI preview" })
	vim.api.nvim_create_user_command("SwaggerPreviewToggle", M.toggle, { desc = "Toggle the OpenAPI preview" })

	local group = vim.api.nvim_create_augroup("SwaggerPreview", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			stop(true)
		end,
	})
end

return M
