return {
	"esmuellert/codediff.nvim",
	version = "v4.0.6",
	cmd = { "CodeDiff", "GitDiff", "GitHistory", "GitReview", "FileDiff" },
	keys = {
		{ "<leader>gd", "<cmd>GitDiff<cr>", desc = "Repository diff or latest commit" },
		{ "<leader>gh", "<cmd>GitHistory<cr>", desc = "Browse history in review tab" },
		{
			"<leader>gv",
			function()
				require("utils.gitdiff").review()
			end,
			desc = "Review commit changes",
		},
		{
			"<leader>hD",
			function()
				require("utils.gitdiff").file_diff()
			end,
			desc = "Compare file with revision",
		},
	},
	config = function()
		require("codediff").setup({
			diff = { layout = "side-by-side", filler_text = "", cycle_hunks_across_files = true },
			explorer = { auto_open_on_cursor = false, focus_on_select = false },
			history = { position = "left" },
			keymaps = {
				view = {
					next_file = { "]f", "<Tab>" },
					prev_file = { "[f", "<S-Tab>" },
				},
			},
		})
		require("utils.codediff_preview").setup()
		vim.api.nvim_create_user_command("GitDiff", function(opts)
			require("utils.gitdiff").open(opts.bang)
		end, { bang = true, desc = "Review working changes or HEAD; ! exits Neovim on close" })
		vim.api.nvim_create_user_command("GitHistory", function(opts)
			require("utils.gitdiff").history(opts.bang)
		end, { bang = true, desc = "Browse history in review tab; ! exits Neovim on close" })
		vim.api.nvim_create_user_command("GitReview", function(opts)
			require("utils.gitdiff").review(opts.args)
		end, { nargs = "?", desc = "Review one commit, or choose it from a picker" })
		vim.api.nvim_create_user_command("FileDiff", function(opts)
			require("utils.gitdiff").file_diff(opts.args)
		end, { nargs = "?", desc = "Compare current file with a revision, or choose it from a picker" })
	end,
}
