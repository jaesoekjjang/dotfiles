vim.opt.autowrite = true

local opts = { noremap = true, silent = true, buffer = true }
vim.keymap.set("n", "<leader>gb", ":GoBuild<CR>", opts)
vim.keymap.set("n", "<leader>gr", ":GoRun<CR>", opts)
vim.keymap.set("n", "<leader>gtt", ":GoTest<CR>", opts)
vim.keymap.set("n", "<leader>gtf", ":GoTestFunc<CR>", opts)
vim.keymap.set("n", "<leader>gtc", ":GoTestCompile<CR>", opts)
vim.keymap.set("n", "<leader>gc", ":GoCoverage<CR>", opts)
