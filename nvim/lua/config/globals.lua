-- leader키 설정
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.rainbow_active = 1

-- yank 하면 highlight
vim.cmd([[
augroup highlight_yank
autocmd!
au TextYankPost * silent! lua vim.highlight.on_yank({higroup="Search", timeout=300})
augroup END
]])
