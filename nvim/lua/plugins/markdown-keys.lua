local function setup(buf)
	-- ── Helpers ─────────────────────────────────────────────────────────────────

	local function get_lines(s, e)
		return vim.api.nvim_buf_get_lines(buf, s - 1, e, false)
	end

	local function set_line(i, text)
		vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { text })
	end

	local function strip_list(line)
		return (line:gsub("^%s*[-*+] ", ""):gsub("^%s*%d+%. ", ""))
	end

	local function visual_range()
		local s = vim.fn.line("v")
		local e = vim.fn.line(".")
		if s > e then s, e = e, s end
		return s, e
	end

	-- ── Checkbox ─────────────────────────────────────────────────────────────────

	local function toggle_checkbox(s, e)
		for i = s, e do
			local line = get_lines(i, i)[1]
			if line:find("%[ %]") then
				set_line(i, line:gsub("%[ %]", "[x]", 1))
			elseif line:find("%[[xX]%]") then
				set_line(i, line:gsub("%[[xX]%]", "[ ]", 1))
			else
				-- 체크박스 없으면 추가: 리스트 마커 뒤에 삽입, 없으면 "- [ ] " 앞에 붙임
				local new = line:gsub("^(%s*[-*+] )", "%1[ ] ")
				if new == line then
					new = line:gsub("^(%s*%d+%. )", "%1[ ] ")
				end
				if new == line then
					local indent = line:match("^(%s*)") or ""
					new = indent .. "- [ ] " .. vim.trim(line)
				end
				set_line(i, new)
			end
		end
	end

	-- ── List conversion ───────────────────────────────────────────────────────────

	local function to_unordered(s, e)
		for i = s, e do
			local line = get_lines(i, i)[1]
			local indent = line:match("^(%s*)") or ""
			set_line(i, indent .. "- " .. vim.trim(strip_list(line)))
		end
	end

	local function to_ordered(s, e)
		local num = 1
		if s > 1 then
			local prev = get_lines(s - 1, s - 1)[1]
			local n = prev:match("^%s*(%d+)%. ")
			if n then num = tonumber(n) + 1 end
		end
		for i = s, e do
			local line = get_lines(i, i)[1]
			local indent = line:match("^(%s*)") or ""
			set_line(i, indent .. num .. ". " .. vim.trim(strip_list(line)))
			num = num + 1
		end
	end

	-- ── Plain text / Heading conversion ──────────────────────────────────────────

	local function to_plain(s, e)
		for i = s, e do
			local line = get_lines(i, i)[1]
			local text = line
			text = text:gsub("^%s*#+%s+", "")
			text = text:gsub("%[[ xX]%]%s*", "")
			text = vim.trim(strip_list(text))
			local indent = line:match("^(%s*)") or ""
			set_line(i, indent .. text)
		end
	end

	local function to_heading(s, e)
		vim.ui.select({ "# H1", "## H2", "### H3", "#### H4", "##### H5", "###### H6" }, { prompt = "Heading level:" }, function(choice)
			if not choice then return end
			local prefix = choice:match("^(#+)") .. " "
			for i = s, e do
				local line = get_lines(i, i)[1]
				local text = vim.trim(line:gsub("^%s*#+%s+", ""))
				set_line(i, prefix .. text)
			end
		end)
	end

	-- ── Wrap actions ─────────────────────────────────────────────────────────────

	local CALLOUT_TYPES = { "NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION", "ABSTRACT", "TODO", "QUESTION", "BUG", "EXAMPLE", "QUOTE" }

	local function wrap_callout(s, e)
		vim.ui.select(CALLOUT_TYPES, { prompt = "Callout type:" }, function(choice)
			if not choice then return end
			local lines = vim.api.nvim_buf_get_lines(buf, s - 1, e, false)
			local wrapped = { "> [!" .. choice .. "]" }
			for _, line in ipairs(lines) do
				table.insert(wrapped, "> " .. line)
			end
			vim.api.nvim_buf_set_lines(buf, s - 1, e, false, wrapped)
		end)
	end

	local function wrap_codeblock(s, e)
		local lang = vim.fn.input("Language: ")
		vim.api.nvim_buf_set_lines(buf, e, e, false, { "```" })
		vim.api.nvim_buf_set_lines(buf, s - 1, s - 1, false, { "```" .. lang })
	end

	-- ── Picker ───────────────────────────────────────────────────────────────────

	local function md_picker(s, e)
		local feed = function(key)
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "m", false)
		end

		local is_range = e > s
		local actions = {
			{ name = "󰄱  Toggle checkbox",    fn = function() toggle_checkbox(s, e) end },
			{ name = "-  Unordered list",     fn = function() to_unordered(s, e) end },
			{ name = "1. Ordered list",       fn = function() to_ordered(s, e) end },
			{ name = "   Wrap callout",      fn = function() wrap_callout(s, e) end },
			{ name = "   Wrap code block",   fn = function() wrap_codeblock(s, e) end },
			{ name = "   Insert callout",    fn = function() feed("mc") end },
			{ name = "   Insert code block", fn = function() feed("mk") end },
			{ name = "   Toggle render",     fn = function() feed("mr") end },
			{ name = "   Live preview",      fn = function() feed("mp") end },
			{ name = "T  To plain text",      fn = function() to_plain(s, e) end },
			{ name = "#  To heading",         fn = function() to_heading(s, e) end },
		}

		vim.ui.select(
			vim.tbl_map(function(a) return a.name end, actions),
			{ prompt = "Markdown" },
			function(_, idx)
				if idx then actions[idx].fn() end
			end
		)
	end

	-- ── Keymaps ──────────────────────────────────────────────────────────────────

	local map = function(mode, lhs, fn, desc)
		vim.keymap.set(mode, lhs, fn, { buffer = buf, desc = desc })
	end

	-- checkbox
	map("n", "mn", function() toggle_checkbox(vim.fn.line("."), vim.fn.line(".")) end, "Toggle checkbox")
	map("x", "mn", function() local s, e = visual_range(); toggle_checkbox(s, e) end, "Toggle checkbox")

	-- list
	map("n", "mu", function() to_unordered(vim.fn.line("."), vim.fn.line(".")) end, "Unordered list")
	map("x", "mu", function() local s, e = visual_range(); to_unordered(s, e) end, "Unordered list")
	map("n", "mo", function() to_ordered(vim.fn.line("."), vim.fn.line(".")) end, "Ordered list")
	map("x", "mo", function() local s, e = visual_range(); to_ordered(s, e) end, "Ordered list")

	-- callout / codeblock wrap (visual only)
	map("x", "mc", function() local s, e = visual_range(); wrap_callout(s, e) end, "Wrap in callout")
	map("x", "mk", function() local s, e = visual_range(); wrap_codeblock(s, e) end, "Wrap in code block")

	-- inline code
	local fk = function(keys)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
	end
	map("n", "me", function() fk('ciw`<C-r>"`<Esc>') end, "Wrap word in inline code")
	map("x", "me", function()
		if vim.fn.line("v") ~= vim.fn.line(".") then return end
		fk('s`<C-r>"`<Esc>')
	end, "Wrap selection in inline code")

	-- plain text / heading
	map("n", "mx", function() to_plain(vim.fn.line("."), vim.fn.line(".")) end, "To plain text")
	map("x", "mx", function() local s, e = visual_range(); to_plain(s, e) end, "To plain text")
	map("n", "mh", function() to_heading(vim.fn.line("."), vim.fn.line(".")) end, "To heading")
	map("x", "mh", function() local s, e = visual_range(); to_heading(s, e) end, "To heading")

	-- picker
	map("n", "mm", function() md_picker(vim.fn.line("."), vim.fn.line(".")) end, "Markdown actions")
	map("x", "mm", function() local s, e = visual_range(); md_picker(s, e) end, "Markdown actions")

	-- ── Insert: Enter (list-aware) ────────────────────────────────────────────────

	map("i", "<CR>", function()
		local cmp_ok, cmp = pcall(require, "cmp")
		if cmp_ok and cmp.visible() and cmp.get_active_entry() then
			cmp.confirm({ select = false })
			return
		end

		local line = vim.api.nvim_get_current_line()
		local indent, num = line:match("^(%s*)(%d+)%. ")
		local bullet = line:match("^(%s*[-*+] )")
		local prefix, has_content

		if indent and num then
			has_content = #line > #(indent .. num .. ". ")
			prefix = indent .. tostring(tonumber(num) + 1) .. ". "
		elseif bullet then
			has_content = #line > #bullet
			prefix = bullet
		end

		if prefix then
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))
			if not has_content then
				vim.api.nvim_set_current_line("")
			else
				local after = line:sub(col + 1)
				vim.api.nvim_set_current_line(line:sub(1, col))
				vim.api.nvim_buf_set_lines(buf, row, row, false, { prefix .. after })
				vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
			end
		else
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
		end
	end, "Enter (list-aware)")

	-- ── Insert: Tab / Shift-Tab ───────────────────────────────────────────────────

	map("i", "<Tab>", function()
		local cmp_ok, cmp = pcall(require, "cmp")
		if cmp_ok and cmp.visible() and cmp.get_active_entry() then
			cmp.confirm({ select = true })
			return
		end
		local ls_ok, ls = pcall(require, "luasnip")
		if ls_ok and ls.jumpable(1) then ls.jump(1); return end
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-t>", true, false, true), "n", false)
	end, "Indent")

	map("i", "<S-Tab>", function()
		local ls_ok, ls = pcall(require, "luasnip")
		if ls_ok and ls.jumpable(-1) then ls.jump(-1); return end
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-d>", true, false, true), "n", false)
	end, "Unindent")
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "mdx" },
	callback = function(ev) setup(ev.buf) end,
})

return {}
