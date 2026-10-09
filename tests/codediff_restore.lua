-- Run from the dotfiles root: nvim --headless -u NONE -l tests/codediff_restore.lua
-- Uses installed CodeDiff and nui.nvim; all Git changes stay in a temporary repo.
local root=vim.fn.getcwd()
vim.opt.rtp:prepend(root..'/nvim')
for _,name in ipairs({'nui.nvim','plenary.nvim','codediff.nvim'}) do vim.opt.rtp:append(vim.fn.expand('~/.local/share/nvim/lazy/'..name)) end
vim.opt.swapfile=false
vim.opt.hidden=true
dofile(root..'/nvim/lua/plugins/codediff.lua').config()
local repo=vim.fn.tempname()
vim.fn.mkdir(repo,'p'); repo=vim.uv.fs_realpath(repo)
local function git(...) return vim.system({'git','-C',repo,...}):wait() end
git('init'); git('config','user.email','test@example.com'); git('config','user.name','Test')
vim.fn.writefile({'one','two'},repo..'/b.txt'); vim.fn.writefile({'one','two'},repo..'/a.txt'); git('add','.'); git('commit','-m','base')
vim.fn.writefile({'one','changed'},repo..'/a.txt'); vim.fn.writefile({'one','changed'},repo..'/b.txt')
require('utils.codediff_review').explorer(repo)
local lc=require('codediff.ui.lifecycle')
assert(vim.wait(5000,function() local s=lc.get_session(vim.api.nvim_get_current_tabpage()); return s and s.modified and s.modified.relative=='a.txt' end))
vim.wait(300)
local tab=vim.api.nvim_get_current_tabpage(); local s=lc.get_session(tab)
assert(s.compact_mode == true, 'compact by default')
local explorer=lc.get_panel_view(tab)
vim.api.nvim_set_current_win(explorer.winid)
vim.wait(100)
local panel_buffer=explorer.bufnr
local panel_window=explorer.winid
local reposition=vim.fn.maparg('gP','n',false,true).callback
assert(type(reposition)=='function', 'panel position key')
reposition()
assert(vim.api.nvim_win_get_position(panel_window)[1] > vim.api.nvim_win_get_position(s.modified_win)[1], 'panel below diff')
require('codediff.ui.explorer').toggle_visibility(explorer)
require('codediff.ui.explorer').toggle_visibility(explorer)
assert(vim.api.nvim_win_get_position(explorer.winid)[1] > vim.api.nvim_win_get_position(s.modified_win)[1], 'reshown panel stays below')
reposition()
assert(vim.api.nvim_win_get_position(explorer.winid)[2] < vim.api.nvim_win_get_position(s.modified_win)[2], 'panel left of diff')
assert(explorer.bufnr==panel_buffer, 'position preserves panel buffer')
vim.api.nvim_set_current_win(explorer.winid)
local selected=vim.deepcopy(explorer.data.current_selection)
local toggle=vim.fn.maparg('<C-p>','n',false,true).callback
assert(type(toggle)=='function', 'preview key in explorer')
toggle()
local function find_file(name)
  for row,line in ipairs(vim.api.nvim_buf_get_lines(explorer.bufnr,0,-1,false)) do
    if line:find(name,1,true) then
      vim.api.nvim_win_set_cursor(explorer.winid,{row,0})
      vim.api.nvim_exec_autocmds('CursorMoved',{})
      return
    end
  end
  error('missing explorer file '..name)
end
find_file('b.txt')
assert(vim.wait(3000,function() return explorer.data.current_selection.path=='b.txt' end), 'preview follows cursor')
toggle()
find_file('a.txt')
assert(explorer.data.current_selection.path=='b.txt', 'disabled preview leaves selection')
explorer.on_file_select(selected,{force=true})
vim.wait(200)
local function restored()
  local ss=lc.get_session(tab)
  return ss and vim.api.nvim_win_get_buf(ss.modified_win)==ss.modified_bufnr
    and vim.api.nvim_buf_get_name(ss.modified_bufnr)==repo..'/a.txt'
end
vim.api.nvim_set_current_win(s.modified_win)
vim.cmd('enew')
local other=vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(other,0,-1,false,{'unsaved scratch'})
vim.wait(100)
local restore=vim.fn.maparg('gR','n',false,true).callback
assert(type(restore)=='function', 'recovery key on replaced buffer')
restore()
assert(vim.wait(3000,restored), 'restore comparison')
assert(vim.api.nvim_buf_get_lines(other,0,-1,false)[1]=='unsaved scratch', 'preserve edits')
local panel=lc.get_panel_view(tab)
vim.api.nvim_win_close(panel.winid,true); vim.wait(100)
vim.cmd('GitDiffRestore')
assert(vim.wait(3000,function() return vim.api.nvim_win_is_valid(panel.winid) and restored() end), 'restore closed explorer')
s=lc.get_session(tab)
vim.api.nvim_set_current_win(s.modified_win); vim.cmd('enew')
require('utils.codediff_review').explorer(repo)
assert(vim.wait(3000,restored), 'GitDiff restores buffers')
vim.cmd('tabnew')
assert(vim.fn.maparg('gR','n')=='', 'review key does not leak to ordinary tab')
vim.api.nvim_set_current_tabpage(tab); vim.wait(100)
s=lc.get_session(tab)
vim.api.nvim_win_close(s.original_win,true); vim.wait(200)
assert(not lc.get_session(tab),'upstream tears down closed comparison')
vim.cmd('cd '..vim.fn.fnameescape(repo))
vim.cmd('GitDiffRestore')
assert(vim.wait(3000,function() local ss=lc.get_session(vim.api.nvim_get_current_tabpage()); return ss and ss.git_root==repo end),'recreate closed comparison')
git('add','.'); git('commit','-m','second')
local head=vim.trim(git('rev-parse','HEAD').stdout)
local base=vim.trim(git('rev-parse','HEAD^').stdout)
require('utils.codediff_review').history(repo)
assert(vim.wait(3000,function() return lc.get_panel_name(vim.api.nvim_get_current_tabpage())=='history' end),'history opens')
vim.wait(200)
local ht=vim.api.nvim_get_current_tabpage()
local history=lc.get_panel_view(ht)
vim.api.nvim_set_current_win(history.winid); vim.wait(100)
local hp=vim.fn.maparg('<C-p>','n',false,true).callback
assert(type(hp)=='function','history preview binding')
if not lc.get_session(ht).dotfiles_auto_preview then hp() end
local function select_node(predicate)
  for row=1,vim.api.nvim_buf_line_count(history.bufnr) do
    local node=history.tree:get_node(row)
    if node and predicate(node.data) then
      vim.api.nvim_win_set_cursor(history.winid,{row,0})
      vim.api.nvim_exec_autocmds('CursorMoved',{})
      return
    end
  end
  error('missing history node')
end
select_node(function(d) return d.type=='commit' and d.hash==base end)
assert(vim.wait(3000,function() return history.data.current_selection.commit_hash==base end),'preview older commit')
select_node(function(d) return d.type=='commit' and d.hash==head end)
assert(vim.wait(3000,function() return history.data.current_selection.commit_hash==head end),'preview newer commit')
select_node(function(d) return d.type=='file' and d.commit_hash==head and d.path=='b.txt' end)
assert(vim.wait(3000,function() return history.data.current_selection.path=='b.txt' end),'preview history file')
hp()
select_node(function(d) return d.type=='commit' and d.hash==base end)
vim.wait(100)
assert(history.data.current_selection.commit_hash==head,'disabled history preview')
print('PASS: history commit/file preview,  compact default, preview toggle, recovery key, buffer replacement, unsaved edits, closed explorer, GitDiff reuse, closed comparison')
vim.fn.delete(repo,'rf')
vim.cmd('qa!')
