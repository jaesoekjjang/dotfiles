-- leader키 설정
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.rainbow_active = 1

-- 클립보드와 vim yank 연동
vim.api.nvim_set_option("clipboard", "unnamedplus")

-- yank 하면 highlight
vim.cmd([[
augroup highlight_yank
autocmd!
au TextYankPost * silent! lua vim.highlight.on_yank({higroup="Visual", timeout=300})
augroup END
]])
