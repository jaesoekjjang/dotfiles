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
	{
		"cdmill/neomodern.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("neomodern").setup({
				style = "coffeecat", -- choose between 'iceclimber', 'coffeecat', 'darkforest', 'campfire', 'roseprime', 'daylight'
			})
			require("neomodern").load()
		end,
	},
	-- {
	-- 	"slugbyte/lackluster.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
 --    config = function()
 --      vim.cmd.colorscheme("lackluster-night")
 --    end
	-- },
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({
				options = {
					theme = "neomodern",
				},
				sections = {
					lualine_c = {
						{ "filename", path = 4 },
					},
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
