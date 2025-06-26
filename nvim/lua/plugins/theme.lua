return {
	-- {
	-- 	-- {
	-- 	-- 	"sainnhe/gruvbox-material",
	-- 	-- 	lazy = false,
	-- 	-- 	priority = 1000,
	-- 	-- 	config = function()
	-- 	-- 		-- Optionally configure and load the colorscheme
	-- 	-- 		-- directly inside the plugin declaration.
	-- 	-- 		vim.g.gruvbox_material_enable_italic = true
	-- 	-- 		vim.g.gruvbox_material_background = "hard"
	-- 	-- 		vim.g.gruvbox_material_better_performance = 1
	-- 	--
	-- 	-- vim.cmd.colorscheme("gruvbox-material")
	-- 	-- 	end,
	-- 	-- },
	-- {
	-- 	"metalelf0/base16-black-metal-scheme",
	-- },
	-- {
	-- 	"chama-chomo/grail",
	-- 	version = false,
	-- 	lazy = false,
	-- 	priority = 1000,
	-- },
	-- {
	-- 	"cdmill/neomodern.nvim",
	-- 	commit = "2e80b10e13bba981fa011551ded8ee59985ec30d", --coffeecat 바뀌기 전 마지막 커밋
	-- 	lazy = false,
	-- 	priority = 1000,
	-- 	config = function()
	-- 		require("neomodern").setup({
	-- 			variant = "light",
	-- 			style = "iceclimber", -- choose between 'iceclimber', 'coffeecat', 'darkforest', 'campfire', 'roseprime', 'daylight'
	-- 		})
	-- 		require("neomodern").load()
	-- 		vim.cmd("colorscheme iceclimber")
	-- 	end,
	-- },
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				compile = false, -- enable compiling the colorscheme
				undercurl = true, -- enable undercurls
				commentStyle = { italic = true },
				functionStyle = {},
				keywordStyle = { italic = true },
				statementStyle = { bold = true },
				typeStyle = {},
				transparent = false, -- do not set background color
				dimInactive = false, -- dim inactive window `:h hl-NormalNC`
				terminalColors = true, -- define vim.g.terminal_color_{0,17}
				colors = { -- add/modify theme and palette colors
					palette = {},
					theme = {
						wave = {},
						lotus = {},
						dragon = {},
						all = {
							ui = {
								bg_gutter = "none",
							},
						},
					},
				},
				overrides = function(colors) -- add/modify highlights
					return {}
				end,
				theme = "wave", -- Load "wave" theme
				background = { -- map the value of 'background' option to a theme
					dark = "wave", -- try "dragon" !
					light = "lotus",
				},
			})

			vim.cmd("colorscheme kanagawa")
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({
				options = {
					theme = "kanagawa",
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diagnostics" },
					lualine_c = { "filename" },
					lualine_x = { "encoding", "filetype" },
					lualine_y = { "progress", "location" },
					lualine_z = { { "datetime", style = "%m월 %d일(%w) %H:%M" } },
					-- lualine_x = { "encoding", "fileformat", "filetype" },
					-- lualine_y = { "progress" },
					-- lualine_z = { "location" },
				},
			})
		end,
	},
}

-- ## flavor
-- 1. darkforest
-- 2. coffeecat
-- 3. habamax
-- 4. base-black-metal-nile
-- 5. grail
