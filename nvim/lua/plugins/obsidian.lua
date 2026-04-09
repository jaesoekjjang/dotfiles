return {
	"epwalsh/obsidian.nvim",
	version = "*",
	lazy = true,
	ft = "markdown",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		workspaces = {
			{
				name = "personal",
				path = "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault",
			},
		},
		completion = {
			nvim_cmp = true,
			min_chars = 2,
		},
		mappings = {},
		daily_notes = {
			folder = "Daily",
			date_format = "%Y-%m-%d",
			template = "Daily.md",
		},
		templates = {
			folder = "Config/Templates",
		},
		attachments = {
			img_folder = "Assets",
		},
		note_id_func = function(title)
			return title or tostring(os.time())
		end,
		new_notes_location = "notes_subdir",
		wiki_link_func = "use_alias_only",
		follow_url_func = function(url)
			vim.fn.jobstart({ "open", url })
		end,
		ui = { enable = false },
	},
	keys = {
		-- ── Picker ─────────────────────────────────────────────────────────────────
		{
			"<leader>oo",
			function()
				local vault = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
				local actions = {
					{
						name = "Daily note (날짜 선택)",
						fn = function()
							local files = vim.fn.globpath(vault .. "/Daily", "*.md", 0, 1)
							table.sort(files, function(a, b) return a > b end)

							local tpickers = require("telescope.pickers")
							local tfinders = require("telescope.finders")
							local conf = require("telescope.config").values
							local tactions = require("telescope.actions")
							local action_state = require("telescope.actions.state")

							local NEW_DATE = "＋ 새 날짜..."

							local function open_or_create(date)
								local filepath = vault .. "/Daily/" .. date .. ".md"
								if vim.fn.filereadable(filepath) == 0 then
									local tmpl = vault .. "/Config/Templates/Daily.md"
									local tf = io.open(tmpl, "r")
									if tf then
										local content = tf:read("*all"):gsub("{{date}}", date)
										tf:close()
										local nf = io.open(filepath, "w")
										if nf then nf:write(content); nf:close() end
									end
								end
								vim.cmd("edit " .. vim.fn.fnameescape(filepath))
							end

							tpickers.new({}, {
								prompt_title = "Daily Notes",
								finder = tfinders.new_table({
									results = vim.list_extend({ NEW_DATE }, files),
									entry_maker = function(entry)
										if entry == NEW_DATE then
											return { value = NEW_DATE, display = NEW_DATE, ordinal = "0000-00-00" }
										end
										local date = vim.fn.fnamemodify(entry, ":t:r")
										return { value = entry, display = date, ordinal = date, path = entry }
									end,
								}),
								sorter = conf.generic_sorter({}),
								previewer = conf.file_previewer({}),
								attach_mappings = function(prompt_bufnr)
									tactions.select_default:replace(function()
										tactions.close(prompt_bufnr)
										local selected = action_state.get_selected_entry()
										if selected.value == NEW_DATE then
											local date = vim.fn.input("날짜 (YYYY-MM-DD): ")
											if date ~= "" then open_or_create(date) end
										else
											open_or_create(vim.fn.fnamemodify(selected.path, ":t:r"))
										end
									end)
									return true
								end,
							}):find()
						end,
					},
					{ name = "태그 탐색", fn = function() vim.cmd("ObsidianTags") end },
					{
						name = "기한 있는 할 일",
						fn = function()
							require("telescope.builtin").grep_string({
								search = "- \\[ \\].*📅",
								use_regex = true,
								cwd = vault,
								prompt_title = "기한 있는 할 일",
							})
						end,
					},
					}
				vim.ui.select(
					vim.tbl_map(function(a) return a.name end, actions),
					{ prompt = "Obsidian" },
					function(_, idx)
						if idx then actions[idx].fn() end
					end
				)
			end,
			mode = { "n", "v" },
			desc = "Obsidian...",
		},
		-- ── Flat ────────────────────────────────────────────────────────────────
		{
			"<leader>or",
			function()
				local vault = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
				local current_abs = vim.api.nvim_buf_get_name(0)
				local current_rel = current_abs:gsub(vim.pesc(vault) .. "/", "")
				local current_dir = vim.fn.fnamemodify(current_rel, ":h")
				local current_name = vim.fn.fnamemodify(current_rel, ":t:r")

				if current_dir == "." then current_dir = "" end

				local excluded = {
					Config = true, Excalidraw = true, Assets = true, Tags = true,
					[".trash"] = true, [".obsidian"] = true, [".zk"] = true,
				}

				local function get_dirs()
					local dirs = { "" }
					local handle = vim.loop.fs_scandir(vault)
					while handle do
						local name, ftype = vim.loop.fs_scandir_next(handle)
						if not name then break end
						if ftype == "directory" and not excluded[name] and not name:match("^%.") then
							table.insert(dirs, name)
							local sub = vim.loop.fs_scandir(vault .. "/" .. name)
							while sub do
								local sname, sftype = vim.loop.fs_scandir_next(sub)
								if not sname then break end
								if sftype == "directory" then
									table.insert(dirs, name .. "/" .. sname)
								end
							end
						end
					end
					return dirs
				end

				local pickers = require("telescope.pickers")
				local finders = require("telescope.finders")
				local conf = require("telescope.config").values
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				pickers.new({}, {
					prompt_title = "이동할 폴더",
					default_text = current_dir,
					finder = finders.new_table({
						results = get_dirs(),
						entry_maker = function(dir)
							return {
								value = dir,
								display = dir ~= "" and dir or "(vault root)",
								ordinal = dir,
							}
						end,
					}),
					sorter = conf.generic_sorter({}),
					attach_mappings = function(prompt_bufnr)
						actions.select_default:replace(function()
							actions.close(prompt_bufnr)
							local dest_dir = action_state.get_selected_entry().value
							local new_name = vim.fn.input({ prompt = "이름: ", default = current_name })
							if new_name == "" then return end
							local new_path = dest_dir ~= "" and (dest_dir .. "/" .. new_name) or new_name
							vim.cmd("ObsidianRename " .. vim.fn.fnameescape(new_path))
						end)
						return true
					end,
				}):find()
			end,
			desc = "Move/Rename note",
		},
		{ "<leader>of", "<cmd>ObsidianQuickSwitch<cr>",              desc = "Find note" },
		{ "<leader>os", "<cmd>ObsidianSearch<cr>",                   desc = "Search notes" },
		{ "<leader>ol", "<cmd>ObsidianLink<cr>",          mode = { "n", "v" }, desc = "Link note" },
		{ "<leader>oe", ":'<,'>ObsidianExtractNote<CR>", mode = "v", desc = "Extract to new note" },
		{
			"<leader>oc",
			function()
				local vault = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
				local pickers = require("telescope.pickers")
				local finders = require("telescope.finders")
				local conf = require("telescope.config").values
				local actions = require("telescope.actions")
				local action_state = require("telescope.actions.state")

				local excluded = { Config = true, Excalidraw = true, Assets = true, [".trash"] = true, [".obsidian"] = true, [".zk"] = true }

				local function get_dirs()
					local dirs = { "" }
					local handle = vim.loop.fs_scandir(vault)
					while handle do
						local name, ftype = vim.loop.fs_scandir_next(handle)
						if not name then break end
						if ftype == "directory" and not excluded[name] and not name:match("^%.") then
							table.insert(dirs, name)
							local sub = vim.loop.fs_scandir(vault .. "/" .. name)
							while sub do
								local sname, sftype = vim.loop.fs_scandir_next(sub)
								if not sname then break end
								if sftype == "directory" then
									table.insert(dirs, name .. "/" .. sname)
								end
							end
						end
					end
					return dirs
				end

				local function pick_title_and_create(template, folder)
					local title = vim.fn.input("Note title: ")
					if title == "" then return end
					local path = folder ~= "" and (folder .. "/" .. title) or title
					vim.cmd("ObsidianNew " .. path)
					if template then
						vim.cmd("ObsidianTemplate " .. template)
					end
				end

				local function pick_folder(template)
					pickers.new({}, {
						prompt_title = "Select Folder",
						finder = finders.new_table({
							results = get_dirs(),
							entry_maker = function(dir)
								return {
									value = dir,
									display = dir ~= "" and dir or "(vault root)",
									ordinal = dir,
								}
							end,
						}),
						sorter = conf.generic_sorter({}),
						attach_mappings = function(prompt_bufnr)
							actions.select_default:replace(function()
								actions.close(prompt_bufnr)
								pick_title_and_create(template, action_state.get_selected_entry().value)
							end)
							return true
						end,
					}):find()
				end

				local template_files = vim.fn.globpath(vault .. "/Config/Templates", "*.md", 0, 1)
				pickers.new({}, {
					prompt_title = "Select Template",
					finder = finders.new_table({
						results = template_files,
						entry_maker = function(file)
							return {
								value = file,
								display = vim.fn.fnamemodify(file, ":t:r"),
								ordinal = vim.fn.fnamemodify(file, ":t:r"),
								path = file,
							}
						end,
					}),
					sorter = conf.generic_sorter({}),
					previewer = conf.file_previewer({}),
					attach_mappings = function(prompt_bufnr)
						actions.select_default:replace(function()
							actions.close(prompt_bufnr)
							local template = vim.fn.fnamemodify(action_state.get_selected_entry().path, ":t:r")
							pick_folder(template)
						end)
						return true
					end,
				}):find()
			end,
			desc = "Create note with template",
		},
		{ "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks" },
		{ "<leader>od", "<cmd>ObsidianToday<cr>",    desc = "Open today's note" },
		{
			"<leader>ot",
			function()
				local choices = {
					{ label = "오늘 (" .. os.date("%Y-%m-%d") .. ")",     date = os.date("%Y-%m-%d") },
					{ label = "내일 (" .. os.date("%Y-%m-%d", os.time() + 86400) .. ")", date = os.date("%Y-%m-%d", os.time() + 86400) },
					{ label = "직접 입력",                                  date = nil },
				}
				vim.ui.select(
					vim.tbl_map(function(c) return c.label end, choices),
					{ prompt = "기한:" },
					function(_, idx)
						if not idx then return end
						local date = choices[idx].date
						if not date then
							date = vim.fn.input("날짜 (YYYY-MM-DD): ")
							if date == "" then return end
						end
						local line = vim.api.nvim_get_current_line()
						vim.api.nvim_set_current_line(line .. " 📅 " .. date)
					end
				)
			end,
			desc = "Add due date to task",
		},
		{ "<leader>ov", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image from clipboard" },
		{
			"<leader>oi",
			function()
				local title = vim.fn.input("Note title: ")
				if title ~= "" then
					vim.cmd("ObsidianNew Inbox/" .. title)
				end
			end,
			desc = "New inbox note",
		},
		{
			"<leader>om",
			function()
				local vault = vim.fn.expand("~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault")
				local projects = vim.fn.globpath(vault .. "/Projects", "*", 0, 1)
				projects = vim.tbl_filter(function(p)
					return vim.fn.isdirectory(p) == 1
				end, projects)
				projects = vim.tbl_map(function(p)
					return vim.fn.fnamemodify(p, ":t")
				end, projects)

				vim.ui.select(projects, { prompt = "Select project: " }, function(project)
					if not project then return end
					local date = os.date("%Y-%m-%d")
					local filepath = vault .. "/Projects/" .. project .. "/회의록/" .. date .. ".md"
					local template_path = vault .. "/Config/Templates/회의록.md"

					local f = io.open(template_path, "r")
					local content = f:read("*all")
					f:close()

					content = content:gsub("{{date}}", date)

					vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
					local out = io.open(filepath, "w")
					out:write(content)
					out:close()

					vim.cmd("edit " .. vim.fn.fnameescape(filepath))
				end)
			end,
			desc = "New meeting note",
		},
	},
}
