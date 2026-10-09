return {
	{
		"numToStr/Comment.nvim",
	},
	{
		"JoosepAlviste/nvim-ts-context-commentstring",
		config = function()
			require("ts_context_commentstring").setup({ enable_autocmd = false })
			local pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
			require("Comment").setup({
				pre_hook = function(ctx)
					-- Neovim can return nil without throwing when a buffer has no parser.
					local ok, parser = pcall(vim.treesitter.get_parser, 0)
					if ok and parser then
						return pre_hook(ctx)
					end
					return vim.bo.commentstring
				end,
			})
		end,
	},
}
