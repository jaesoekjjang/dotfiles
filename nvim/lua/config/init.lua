-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- VSCode 환경 감지
local is_vscode = vim.g.vscode ~= nil

require("config.globals")

-- 환경별 설정 로드
if not is_vscode then
	require("config.keymaps")
	require("config.options")
	require("config.cmd")
else
	-- VSCode 전용 설정
	require("config.options-vscode")
	require("config.keymaps-vscode")
	vim.highlight.on_yank({ higroup = "Search" })
end

-- Setup lazy.nvim
local opts = {}

-- VSCode 환경이 아닐 때는 plugins 디렉토리 로드
if not is_vscode then
	require("lazy").setup("plugins", opts)
else
	-- VSCode에서는 최소한의 플러그인만 로드
	require("lazy").setup("plugins-vscode", opts)
end
