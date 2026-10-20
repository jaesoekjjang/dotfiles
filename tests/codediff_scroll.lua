-- Run: nvim --headless -u NONE -l tests/codediff_scroll.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. '/nvim')
for _, name in ipairs({ 'nui.nvim', 'plenary.nvim', 'codediff.nvim' }) do
  vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/' .. name))
end
vim.opt.swapfile = false
vim.o.lines = 30
vim.o.columns = 140
vim.cmd('runtime plugin/codediff.lua')
dofile(root .. '/nvim/lua/plugins/codediff.lua').config()
require('codediff.config').options.diff.compact = false
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, 'p')
repo = vim.uv.fs_realpath(repo)
local function git(...)
  local result = vim.system({ 'git', '-C', repo, ... }):wait()
  assert(result.code == 0, result.stderr)
end
git('init')
git('config', 'user.email', 'test@example.com')
git('config', 'user.name', 'Test')
local lines = {}
for i = 1, 200 do lines[i] = 'line ' .. i end
vim.fn.writefile(lines, repo .. '/a.txt')
git('add', '.')
git('commit', '-m', 'base')
lines[100] = 'changed'
vim.fn.writefile(lines, repo .. '/a.txt')
require('utils.codediff_review').explorer(repo)
local lc = require('codediff.ui.lifecycle')
assert(vim.wait(5000, function()
  local s = lc.get_session(vim.api.nvim_get_current_tabpage())
  return s and s.modified and s.modified.relative == 'a.txt'
end), 'comparison loaded')
vim.wait(300)
local tab = vim.api.nvim_get_current_tabpage()
local s = lc.get_session(tab)
local panel = lc.get_panel_view(tab)
local function top(win)
  return vim.api.nvim_win_call(win, function() return vim.fn.winsaveview().topline end)
end
for _, win in ipairs({ s.original_win, s.modified_win }) do
  vim.api.nvim_win_call(win, function() vim.cmd('normal! ggzt') end)
end
vim.api.nvim_set_current_win(panel.winid)
vim.wait(100)
local cursor = vim.api.nvim_win_get_cursor(panel.winid)
local selection = vim.deepcopy(panel.data.current_selection)
local function scroll(key)
  local callback = vim.fn.maparg(key, 'n', false, true).callback
  assert(type(callback) == 'function', 'explorer scroll mapping: ' .. key)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'xt', false)
  assert(vim.api.nvim_get_current_win() == panel.winid, 'explorer keeps focus')
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(panel.winid), cursor), 'explorer cursor unchanged')
  assert(vim.deep_equal(panel.data.current_selection, selection), 'selected file unchanged')
end
local initial = top(s.modified_win)
scroll('<C-e>')
assert(top(s.modified_win) == initial + 1, 'one line down')
assert(top(s.original_win) == top(s.modified_win), 'both diff panes scroll together')
scroll('<C-y>')
assert(top(s.modified_win) == initial, 'one line up')
vim.api.nvim_feedkeys('3' .. vim.api.nvim_replace_termcodes('<C-e>', true, false, true), 'xt', false)
assert(top(s.modified_win) == initial + 3, 'counted scroll through actual key mapping')
assert(vim.api.nvim_get_current_win() == panel.winid, 'counted scroll keeps explorer focus')
scroll('<C-d>')
local down = top(s.modified_win)
assert(down > initial + 1, 'half page down')
assert(top(s.original_win) == down, 'half page keeps panes in sync')
scroll('<C-u>')
assert(top(s.modified_win) < down, 'half page up')
-- Scroll commands at file edges are harmless.
for _ = 1, 25 do scroll('<C-d>') end
for _ = 1, 25 do scroll('<C-u>') end
assert(top(s.modified_win) == 1, 'returns to start')
-- The original pane is the preview for deleted files.
local previous_side = s.single_side
s.single_side = 'original'
scroll('<C-e>')
assert(top(s.original_win) == 2, 'original-only comparison scrolls')
s.single_side = previous_side
vim.api.nvim_set_current_win(s.modified_win)
assert(vim.fn.maparg('<C-d>', 'n') == '', 'diff body retains normal scroll keys')
vim.api.nvim_set_current_win(panel.winid)
local callback = vim.fn.maparg('<C-e>', 'n', false, true).callback
local replacement = vim.api.nvim_create_buf(true, false)
vim.api.nvim_win_set_buf(s.modified_win, replacement)
callback()
assert(vim.api.nvim_get_current_win() == panel.winid, 'replaced comparison is safely ignored')
vim.cmd('tabclose!')
vim.fn.delete(repo, 'rf')
print('PASS: explorer preview scrolling, synchronized panes, focus, selection, boundaries, replaced buffer')
vim.cmd('qa!')
