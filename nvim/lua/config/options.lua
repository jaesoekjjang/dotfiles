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

-- line number
opt.number = true
opt.relativenumber = true
opt.termguicolors = true -- 255 이상의 color 지원
opt.signcolumn = "yes" -- line number가 표시되는 열의 공간 확보

-- etc
opt.encoding = "UTF-8"
opt.cmdheight = 1
opt.scrolloff = 10
opt.mouse:append("a")
