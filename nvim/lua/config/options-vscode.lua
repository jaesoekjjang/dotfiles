local opt = vim.opt

-- tab/indent
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.wrap = false
opt.autoindent = true
opt.modifiable = true
opt.splitbelow = true
opt.splitright = true
-- search
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- opt.number = true
-- opt.relativenumber = true
-- opt.signcolumn = "yes"

-- 기본 편집 설정
opt.encoding = "UTF-8"
opt.completeopt = "menuone,popup,noselect"
opt.clipboard = "unnamedplus"
