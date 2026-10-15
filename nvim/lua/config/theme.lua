local M = {}
local uv = vim.uv or vim.loop
local watcher, config_file, last_requested, generation

local mappings = {
	zenbones_light_dim = { scheme = "zenbones", background = "light", lightness = "dim" },
	zenbones = { scheme = "zenbones", background = "light" },
	zenwritten_light = { scheme = "zenwritten", background = "light" },
	zenwritten_dark = { scheme = "zenwritten", background = "dark" },
	zenbones_light = { scheme = "zenbones", background = "light" },
	zenbones_dark = { scheme = "zenbones", background = "dark" },
	rose_pine = { scheme = "rose-pine-main", background = "dark" },
	rose_pine_moon = { scheme = "rose-pine-moon", background = "dark" },
	everforest_light_hard = { scheme = "everforest", background = "light", everforest = "hard" },
	everforest_light_medium = { scheme = "everforest", background = "light", everforest = "medium" },
	everforest_light_soft = { scheme = "everforest", background = "light", everforest = "soft", foreground = "#4d5a62" },
	rose_pine_dawn = { scheme = "rose-pine-dawn", background = "light" },
	rose_pine_dawn_official = { scheme = "rose-pine-dawn", background = "light" },
	kanagawa_dragon = { scheme = "kanagawa-dragon", background = "dark" },
	monokai_pro_light = { scheme = "monokai-pro-light", background = "light", monokai = "light" },
}
local fallback = { scheme = "kanagawa-dragon", background = "dark" }

function M.read_theme(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local in_appearance, selected = false, nil
	for line in file:lines() do
		local section = line:match("^%s*%[([^%]]+)%]")
		if section then
			in_appearance = section == "appearance"
		elseif in_appearance then
			local _, theme = line:match("^%s*theme%s*=%s*([\"'])([%w_-]*)%1")
			if theme then
				selected = theme
			end
		end
	end
	file:close()
	return selected
end

function M.resolve(theme)
	return mappings[theme] or fallback
end

function M.apply(force)
	local selected = M.read_theme(config_file)
	-- Ignore a briefly missing file during replacement after initial startup.
	if selected == nil and last_requested ~= nil and not force then
		return
	end
	local requested = selected or ""
	if requested == last_requested and not force then
		return
	end
	local choice = M.resolve(requested)
	vim.o.background = choice.background
	local ok = pcall(function()
		if choice.scheme == "zenbones" then
			vim.g.zenbones_lightness = choice.lightness
		end
		if choice.everforest then
			vim.g.everforest_background = choice.everforest
			vim.g.everforest_transparent_background = 0
			-- Match the custom darker text in our TUIOS Soft palette.
			vim.g.everforest_colors_override = choice.foreground and { fg = { choice.foreground, "242" } } or vim.empty_dict()
		end
		if choice.monokai then
			require("monokai-pro").setup({
				filter = "light",
				transparent_background = false,
			})
		end
		vim.cmd.colorscheme(choice.scheme)
	end)
	if not ok then
		vim.o.background = fallback.background
		vim.cmd.colorscheme(fallback.scheme)
	end
	last_requested = requested
end

function M.stop()
	if watcher then
		watcher:stop()
		watcher:close()
		watcher = nil
	end
end

function M.setup(opts)
	M.stop()
	config_file = opts and opts.config_file
		or (vim.fn.has("mac") == 1 and vim.fn.expand("~/Library/Application Support/tuios/config.toml"))
		or ((vim.env.XDG_CONFIG_HOME or vim.fn.expand("~/.config")) .. "/tuios/config.toml")
	last_requested, generation = nil, 0
	M.apply(true)
	local group = vim.api.nvim_create_augroup("DotfilesThemeSync", { clear = true })
	vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = function() M.apply() end })
	vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })
	vim.api.nvim_create_user_command("ThemeSync", function() M.apply(true) end, {})
	-- Watch the directory: TUIOS saves by replacing the config file's inode.
	watcher = uv.new_fs_event()
	local ok = watcher:start(vim.fn.fnamemodify(config_file, ":h"), {}, vim.schedule_wrap(function(err, name)
		if err or (name and vim.fn.fnamemodify(name, ":t") ~= "config.toml") then
			return
		end
		generation = generation + 1
		local current = generation
		vim.defer_fn(function()
			if current == generation then
				M.apply()
			end
		end, 100)
	end))
	if not ok then
		M.stop() -- FocusGained and :ThemeSync still work without a watcher.
	end
end

return M
