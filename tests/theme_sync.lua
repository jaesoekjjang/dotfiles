-- nvim --headless -u NONE -l tests/theme_sync.lua
local root = vim.fn.getcwd()
local lazy = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.rtp:prepend(root .. "/nvim")
vim.opt.rtp:append(lazy .. "kanagawa.nvim")
vim.opt.rtp:append(lazy .. "rose-pine")
vim.opt.rtp:append(lazy .. "monokai-pro.nvim")
vim.opt.rtp:append(lazy .. "everforest")
vim.opt.rtp:append(lazy .. "lush.nvim")
vim.opt.rtp:append(lazy .. "zenbones.nvim")
vim.opt.termguicolors = true
require("kanagawa").setup({ theme = "dragon", background = { dark = "dragon", light = "lotus" } })
require("rose-pine").setup({ styles = { transparency = false } })

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local config = directory .. "/config.toml"
local function write(theme)
	local temporary = directory .. "/config.new"
	vim.fn.writefile({ "[appearance]", "theme = '" .. theme .. "'", "[other]", "theme = 'ignored'" }, temporary)
	assert(vim.uv.fs_rename(temporary, config))
end
local function expect(scheme, background)
	assert(vim.wait(3000, function()
		return vim.g.colors_name == scheme and vim.o.background == background
	end, 20), "expected " .. scheme .. ", got " .. tostring(vim.g.colors_name))
end
local sync = require("config.theme")
write("rose_pine_dawn_official")
assert(sync.read_theme(config) == "rose_pine_dawn_official")
sync.setup({ config_file = config })
expect("rose-pine", "light")
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(normal.bg == tonumber("faf4ed", 16) and normal.fg == tonumber("464261", 16))

-- Atomic config replacement must update an editor that is already running.
write("kanagawa_dragon")
expect("kanagawa", "dark")
normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(normal.bg == tonumber("181616", 16) and normal.fg == tonumber("c5c9c5", 16))
write("unmapped_theme")
assert(vim.wait(1000, function() return sync.read_theme(config) == "unmapped_theme" end))
vim.wait(200)
expect("kanagawa", "dark")
write("rose_pine_dawn")
expect("rose-pine", "light")

-- Missing or partial config during a save must not flash to the dark fallback.
assert(vim.uv.fs_unlink(config))
sync.apply()
expect("rose-pine", "light")
write("kanagawa_dragon")
sync.apply(true)
expect("kanagawa", "dark")

-- Native Monokai Pro Light palette and live switching from Dragon.
write("monokai_pro_light")
sync.apply(true)
expect("monokai-pro", "light")
normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(normal.bg == tonumber("faf4f2", 16) and normal.fg == tonumber("29242a", 16))
local light = require("monokai-pro").get_scheme().base
assert(light.red == "#e14775" and light.cyan == "#1c8ca8" and light.dimmed3 == "#a59fa0")
write("kanagawa_dragon")
assert(vim.wait(3000, function()
	return vim.g.colors_name == "kanagawa" and vim.o.background == "dark"
end, 20), "live Dragon switch failed")
write("monokai_pro_light")
assert(vim.wait(3000, function()
	return vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == tonumber("faf4f2", 16)
end, 20), "live Light switch failed")

-- Every Everforest contrast must reload despite sharing one colorscheme name.
for _, contrast in ipairs({ "hard", "medium", "soft", "hard" }) do
	local theme = "everforest_light_" .. contrast
	local palette = vim.json.decode(table.concat(vim.fn.readfile(root .. "/tuios/themes/" .. theme .. ".json"), "\n"))
	write(theme)
	assert(vim.wait(3000, function()
		local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		return vim.g.colors_name == "everforest" and hl.bg == tonumber(palette.bg:sub(2), 16)
	end, 20), "live Everforest " .. contrast .. " switch failed")
	expect("everforest", "light")
	normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	assert(normal.fg == tonumber(palette.fg:sub(2), 16))
end
for theme, bg in pairs({ rose_pine = "191724", rose_pine_moon = "232136", rose_pine_dawn = "faf4ed" }) do
	write(theme)
	assert(vim.wait(3000, function()
		return vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == tonumber(bg, 16)
	end, 20), "live " .. theme .. " switch failed")
	expect("rose-pine", theme == "rose_pine_dawn" and "light" or "dark")
end

-- Both Zenbones variants must switch background even with the same scheme name.
for _, variant in ipairs({ "zenwritten", "zenbones" }) do
	for _, background in ipairs({ "light", "dark", "light" }) do
		write(variant .. "_" .. background)
		expect(variant, background)
		local palette = require(variant .. ".palette")[background]
		normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		assert(normal.bg == tonumber(palette.bg.hex:sub(2), 16), variant .. " background mismatch")
		assert(normal.fg == tonumber(palette.fg.hex:sub(2), 16), variant .. " foreground mismatch")
	end
end

-- Dim matches the exported TUIOS palette; returning to default clears dim.
local dim = vim.json.decode(table.concat(vim.fn.readfile(root .. "/tuios/themes/zenbones_light_dim.json"), "\n"))
for _, theme in ipairs({ "zenbones_light_dim", "zenbones_light", "zenbones_light_dim", "zenbones" }) do
	write(theme)
	local bg = theme == "zenbones_light_dim" and dim.bg or "#f0edec"
	assert(vim.wait(3000, function()
		local hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		return vim.g.colors_name == "zenbones" and hl.bg == tonumber(bg:sub(2), 16)
	end, 20), "live " .. theme .. " switch failed")
	expect("zenbones", "light")
	if theme == "zenbones_light_dim" then
		normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		assert(normal.fg == tonumber(dim.fg:sub(2), 16))
		assert(vim.g.terminal_color_1:lower() == dim.red)
	end
end

-- A mapped but unavailable plugin must also fall back to Dragon.
vim.opt.rtp:remove(lazy .. "rose-pine")
write("rose_pine_dawn_official")
sync.apply(true)
expect("kanagawa", "dark")
vim.opt.rtp:append(lazy .. "rose-pine")
sync.apply(true)
expect("rose-pine", "light")

-- Both quote styles and an inline comment in the actual TOML section.
vim.fn.writefile({ "[appearance]", 'theme = "kanagawa_dragon" # preference', "[appearance.sidebar]", "theme = 'ignored'" }, config)
assert(sync.read_theme(config) == "kanagawa_dragon")
sync.apply(true)
expect("kanagawa", "dark")
sync.stop()
vim.fn.delete(config)
sync.setup({ config_file = config })
expect("kanagawa", "dark")
sync.stop()
vim.fn.delete(directory, "rf")
print("theme sync: startup, live replacement, fallbacks and exact palette checks passed")
