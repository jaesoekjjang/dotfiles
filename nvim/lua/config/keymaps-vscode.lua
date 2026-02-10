local mapKey = require("utils.keyMapper").mapKey

-- =====================================================
-- BASIC EDITOR OPERATIONS
-- =====================================================

-- wrap-aware movement
mapKey("j", "gj", "n", { desc = "Move down (wrap-aware)", remap = true })
mapKey("k", "gk", "n", { desc = "Move up (wrap-aware)", remap = true })

-- Delete/change
mapKey("<S-d>", "dd")
mapKey("<S-c>", "cc")
mapKey("du", '"_d', "n", { desc = "Delete without yank" })
mapKey("c", '"_c', "n", { desc = "Change without yank" })

-- motion
-- most left, most right
mapKey("H", "^", { "n", "v", "o" })
mapKey("L", "$", { "n", "v", "o" })

-- pair jump
mapKey(",", "%", "n")
mapKey(",", "%", "v")

-- Toggle search highlight
-- mapKey("<C-n>", "<cmd>set hlsearch!<cr>", "n", { desc = "Toggle search highlight" })

-- Better mark navigation
mapKey("''", [[<Cmd>call VSCodeNotify('cursorUndo')<CR>]], "n", { desc = "Cursor undo" })

-- Fix Ctrl+d/Ctrl+u cursor behavior and visual mode
-- mapKey("<C-d>", "<C-d>", "n", { desc = "Half page down and center" })
-- mapKey("<C-u>", "<C-u>", "n", { desc = "Half page up and center" })
-- mapKey("<C-d>", "<C-d>", "v", { desc = "Half page down and center (visual)" })
-- mapKey("<C-u>", "<C-u>", "v", { desc = "Half page up and center (visual)" })

-- Visual mode indentation (stay in visual mode)
mapKey("<", "<gv", "v", { desc = "Indent left and reselect" })
mapKey(">", ">gv", "v", { desc = "Indent right and reselect" })

-- =====================================================
-- NAVIGATION AND DIAGNOSTICS
-- =====================================================

-- Diagnostic navigation
mapKey("]d", [[<Cmd>call VSCodeNotify('editor.action.marker.next')<CR>]], "n", { desc = "Next diagnostic" })
mapKey("[d", [[<Cmd>call VSCodeNotify('editor.action.marker.prev')<CR>]], "n", { desc = "Previous diagnostic" })
mapKey(
	"]D",
	[[<Cmd>call VSCodeNotify('editor.action.marker.nextInFiles')<CR>]],
	"n",
	{ desc = "Next diagnostic in files" }
)
mapKey(
	"[D",
	[[<Cmd>call VSCodeNotify('editor.action.marker.prevInFiles')<CR>]],
	"n",
	{ desc = "Previous diagnostic in files" }
)

-- Buffer/Editor navigation
mapKey(
	"[b",
	[[<Cmd>call VSCodeNotify('workbench.action.previousEditorInGroup')<CR>]],
	"n",
	{ desc = "Previous editor" }
)
mapKey("]b", [[<Cmd>call VSCodeNotify('workbench.action.nextEditorInGroup')<CR>]], "n", { desc = "Next editor" })
mapKey(
	"<BS>",
	[[<Cmd>call VSCodeNotify('workbench.action.previousEditor')<CR>]],
	"n",
	{ desc = "Go to alternate buffer" }
)
mapKey("<S-BS>", [[<Cmd>call VSCodeNotify('workbench.action.nextEditor')<CR>]], "n", { desc = "Go to next buffer" })

-- Navigation back (after Go to Definition)
mapKey("<C-t>", [[<Cmd>call VSCodeNotify('workbench.action.navigateBack')<CR>]], "n", { desc = "Navigate back" })

-- =====================================================
-- WINDOW AND VIEW MANAGEMENT
-- =====================================================

-- Window splitting
mapKey("<C-'>", [[<Cmd>call VSCodeNotify('workbench.action.splitEditor')<CR>]], "n", { desc = "Split editor right" })
mapKey("<C-;>", [[<Cmd>call VSCodeNotify('workbench.action.splitEditorDown')<CR>]], "n", { desc = "Split editor down" })

-- Window group movement
mapKey(
	"<C-w><S-h>",
	[[<Cmd>call VSCodeNotify('workbench.action.moveEditorToLeftGroup')<CR>]],
	"n",
	{ desc = "Move editor to left group" }
)
mapKey(
	"<C-w><S-l>",
	[[<Cmd>call VSCodeNotify('workbench.action.moveEditorToRightGroup')<CR>]],
	"n",
	{ desc = "Move editor to right group" }
)
mapKey(
	"<C-w><S-k>",
	[[<Cmd>call VSCodeNotify('workbench.action.moveEditorToAboveGroup')<CR>]],
	"n",
	{ desc = "Move editor to above group" }
)
mapKey(
	"<C-w><S-j>",
	[[<Cmd>call VSCodeNotify('workbench.action.moveEditorToBelowGroup')<CR>]],
	"n",
	{ desc = "Move editor to below group" }
)

-- Window group focus
mapKey("]w", [[<Cmd>call VSCodeNotify('workbench.action.focusNextGroup')<CR>]], "n", { desc = "Focus next group" })
mapKey(
	"[w",
	[[<Cmd>call VSCodeNotify('workbench.action.focusPreviousGroup')<CR>]],
	"n",
	{ desc = "Focus previous group" }
)

-- Window maximize/expand
mapKey(
	"<C-w>o",
	[[<Cmd>call VSCodeNotify('workbench.action.toggleMaximizeEditorGroup')<CR>]],
	"n",
	{ desc = "Maximize editor" }
)
mapKey(
	"<C-w>m",
	[[<Cmd>call VSCodeNotify('workbench.action.minimizeOtherEditors')<CR>]],
	"n",
	{ desc = "Expand editor group" }
)
mapKey(
	"<C-w>j",
	[[<Cmd>call VSCodeNotify('workbench.action.joinAllGroups')<CR> <Cmd>call VSCodeNotify('workbench.action.focusActiveEditorGroup')<CR>]],
	"n",
	{ desc = "Join all editor groups" }
)

-- Remove default == mapping
vim.keymap.del("n", "==")

-- View size adjustment
mapKey("-", [[<Cmd>call VSCodeNotify('workbench.action.decreaseViewSize')<CR>]], "n", { desc = "Decrease view size" })
mapKey("=", [[<Cmd>call VSCodeNotify('workbench.action.increaseViewSize')<CR>]], "n", { desc = "Increase view size" })

-- Smart close
mapKey("<C-q>", [[<Cmd>call VSCodeNotify('workbench.action.closeEditorsAndGroup')<CR> <Cmd>call VSCodeNotify('workbench.action.focusActiveEditorGroup')<CR>]], "n", { desc = "Smart close" })

-- =====================================================
-- CODE ACTIONS AND LSP
-- =====================================================

-- Quick actions
mapKey("gq", [[<Cmd>call VSCodeNotify('editor.action.quickFix')<CR>]], "n", { desc = "Quick Fix", nowait = true })
mapKey("gs", [[<Cmd>call VSCodeNotify('editor.action.sourceAction')<CR>]], "n", { desc = "Source Action" })

-- LSP navigation
mapKey("gd", [[<Cmd>call VSCodeNotify('editor.action.revealDefinition')<CR>]], "n", { desc = "Go to definition" })
mapKey("grr", [[<Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>]], "n", { desc = "Go to references" })
mapKey(
	"gt",
	[[<Cmd>call VSCodeNotify('editor.action.goToTypeDefinition')<CR>]],
	"n",
	{ desc = "Go to type definition" }
)
mapKey("gi", [[<Cmd>call VSCodeNotify('editor.action.goToImplementation')<CR>]], "n", { desc = "Go to implementation" })
mapKey("gD", [[<Cmd>call VSCodeNotify('editor.action.goToDeclaration')<CR>]], "n", { desc = "Go to declaration" })

-- Code actions
mapKey("grn", [[<Cmd>call VSCodeNotify('editor.action.rename')<CR>]], "n", { desc = "Rename symbol" })
mapKey("grm", [[<Cmd>call VSCodeNotify('editor.action.refactor')<CR>]], "n", { desc = "Refactor menu" })
mapKey("<leader>cf", [[<Cmd>call VSCodeNotify('editor.action.formatDocument')<CR>]], "n", { desc = "Format document" })

-- Information display
mapKey("gh", [[<Cmd>call VSCodeNotify('editor.action.showDefinitionPreviewHover')<CR>]], "n", { desc = "Show hover" })
mapKey(
	"ge",
	[[<Cmd>call VSCodeNotify('editor.action.showMarkerNavigationDetailsWidget')<CR>]],
	"n",
	{ desc = "Show error details" }
)

-- =====================================================
-- COMMENTS
-- =====================================================

-- mapKey("gcc", [[<Cmd>call VSCodeNotify('editor.action.commentLine')<CR>]], "n", { desc = "Toggle line comment" })
-- mapKey("gc", [[<Cmd>call VSCodeNotify('editor.action.commentLine')<CR>]], "v", { desc = "Toggle comment" })

-- =====================================================
-- CODE FOLDING
-- =====================================================
mapKey("zc", [[<Cmd>call VSCodeNotify('editor.fold')<CR>]], "n", { desc = "Close fold" })
mapKey("zo", [[<Cmd>call VSCodeNotify('editor.unfold')<CR>]], "n", { desc = "Open fold" })
mapKey("zt", [[<Cmd>call VSCodeNotify('editor.toggleFold')<CR>]], "n", { desc = "Toggle fold" })
mapKey("zrc", [[<Cmd>call VSCodeNotify('editor.foldRecursively')<CR>]], "n", { desc = "Close fold recursively" })
mapKey("zro", [[<Cmd>call VSCodeNotify('editor.unfoldRecursively')<CR>]], "n", { desc = "Open fold recursively" })
mapKey("zC", [[<Cmd>call VSCodeNotify('editor.foldAll')<CR>]], "n", { desc = "Close all folds" })
mapKey("zO", [[<Cmd>call VSCodeNotify('editor.unfoldAll')<CR>]], "n", { desc = "Open all folds" })
mapKey("zj", [[<Cmd>call VSCodeNotify('editor.gotoNextFold')<CR>]], "n", { desc = "Go to next fold" })
mapKey("zk", [[<Cmd>call VSCodeNotify('editor.gotoPreviousFold')<CR>]], "n", { desc = "Go to previous fold" })

-- =====================================================
-- SEARCH AND FUZZY FINDING
-- =====================================================

mapKey("<leader>ff", [[<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>]], "n", { desc = "Quick open file" })
mapKey("<leader>fg", [[<Cmd>call VSCodeNotify('periscope.search')<CR>]], "n", { desc = "Search in files" })
mapKey("<leader>fo", [[<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>]], "n", { desc = "Recent files" })
mapKey(
	"<leader>fb",
	[[<Cmd>call VSCodeNotify('workbench.action.showAllEditors')<CR>]],
	"n",
	{ desc = "Show all editors" }
)

-- Symbol navigation
mapKey("<leader>fs", [[<Cmd>call VSCodeNotify('workbench.action.gotoSymbol')<CR>]], "n", { desc = "Go to symbol" })
mapKey(
	"<leader>fS",
	[[<Cmd>call VSCodeNotify('workbench.action.showAllSymbols')<CR>]],
	"n",
	{ desc = "Show all symbols" }
)

-- Problems and diagnostics
mapKey("<leader>d", [[<Cmd>call VSCodeNotify('workbench.actions.view.problems')<CR>]], "n", { desc = "Show problems" })

-- Search configuration
mapKey("<leader>ic", [[<Cmd>call VSCodeNotify('toggleFindCaseSensitive')<CR>]], "n", { desc = "Toggle case sensitive" })
mapKey("<leader>iw", [[<Cmd>call VSCodeNotify('toggleFindWholeWord')<CR>]], "n", { desc = "Toggle whole word" })
mapKey("<leader>ir", [[<Cmd>call VSCodeNotify('toggleFindRegex')<CR>]], "n", { desc = "Toggle regex" })

-- =====================================================
-- File operations
-- =====================================================
mapKey("<leader>Fy", [[<Cmd>call VSCodeNotify('fileutils.copyFileName')<CR>]], "n", { desc = "Copy file path" })
mapKey("<leader>Fn", [[<Cmd>call VSCodeNotify('fileutils.newFile')<CR>]], "n", { desc = "New file" })
mapKey("<leader>FN", [[<Cmd>call VSCodeNotify('fileutils.newFolder')<CR>]], "n", { desc = "New folder" })
mapKey("<leader>Fr", [[<Cmd>call VSCodeNotify('fileutils.renameFile')<CR>]], "n", { desc = "Rename file" })
mapKey("<leader>Fx", [[<Cmd>call VSCodeNotify('fileutils.removeFile')<CR>]], "n", { desc = "Remove file" })
mapKey("<leader>Fm", [[<Cmd>call VSCodeNotify('fileutils.moveFile')<CR>]], "n", { desc = "Move file" })
mapKey("<leader>Fd", [[<Cmd>call VSCodeNotify('fileutils.duplicateFile')<CR>]], "n", { desc = "Duplicate file" })

-- =====================================================
-- SIDEBAR AND EXPLORER
-- =====================================================

-- explorer management
mapKey(
	"<leader>ef",
	[[<Cmd>call VSCodeNotify('workbench.files.action.focusFilesExplorer')<CR>]],
	"n",
	{ desc = "Focus files explorer" }
)
mapKey("<leader>er", [[<Cmd>call VSCodeNotify('revealInExplorer')<CR>]], "n", { desc = "Reveal in explorer" })

mapKey("]s", [[<Cmd>call VSCodeNotify('workbench.action.nextSideBarView')<CR>]], "n", { desc = "Next sidebar view" })
mapKey(
	"[s",
	[[<Cmd>call VSCodeNotify('workbench.action.previousSideBarView')<CR>]],
	"n",
	{ desc = "Previous sidebar view" }
)

-- =====================================================
-- TERMINAL
-- =====================================================

mapKey(
	"<leader>tn",
	[[<Cmd>call VSCodeNotify('workbench.action.createTerminalEditor')<CR>]],
	"n",
	{ desc = "New terminal" }
)

-- Terminal escape
mapKey(
	"<C-x>",
	[[<Cmd>call VSCodeNotify('workbench.action.focusActiveEditorGroup')<CR><Cmd>call VSCodeNotify('workbench.action.closePanel')<CR>]],
	"n",
	{ desc = "Focus editor and close panel" }
)

-- =====================================================
-- VISUAL MODE ENHANCEMENTS
-- =====================================================

-- Text selection and search
mapKey("*", [[<Cmd>call VSCodeNotify('editor.action.selectHighlights')<CR>]], "v", { desc = "Select highlights" })
mapKey(
	"fg",
	[[<Cmd>call VSCodeNotify('editor.action.addSelectionToNextFindMatch')<CR><Cmd>call VSCodeNotify('workbench.action.findInFiles')<CR>]],
	"v",
	{ desc = "Search selected in files" }
)

-- Text manipulation
mapKey("sa", [[<Cmd>call VSCodeNotify('editor.action.sortLinesAscending')<CR>]], "v", { desc = "Sort lines ascending" })
mapKey(
	"sd",
	[[<Cmd>call VSCodeNotify('editor.action.sortLinesDescending')<CR>]],
	"v",
	{ desc = "Sort lines descending" }
)
mapKey("Sb", [[<Cmd>call VSCodeNotify('surround.with')<CR>]], "v", { desc = "VSCode Surround with" })
-- nvim-surround는 기본 키맵 사용: ys, yss, S(visual), ds, cs

-- =====================================================
-- AI
-- =====================================================
-- VsCode, Copilot
mapKey(
	"<leader>an",
	[[<Cmd>call VSCodeNotify('editor.action.inlineSuggest.triggerInlineEditExplicit')<CR>]],
	"n",
	{ desc = "Trigger suggestion" }
)
mapKey(
	"<leader>af",
	[[<Cmd>call VSCodeNotify('workbench.panel.chat.view.copilot.focus')<CR>]],
	"n",
	{ desc = "Focus ai panel" }
)
-- claude code
mapKey("<leader>as", [[<Cmd>call VSCodeNotify('claude-code.insertAtMentioned')<CR>]], "n", {desc = "Send buffer to claude code"})
mapKey("<leader>as", [[<Cmd>call VSCodeNotify('claude-code.insertAtMentioned')<CR>]], "v", {desc = "Send buffer to claude code"})
mapKey("<leader>aa", [[<Cmd>call VSCodeNotify('claude-code.acceptProposedDiff')<CR>]], "v", {desc = "Accept suggestion"})
mapKey("<leader>ar", [[<Cmd>call VSCodeNotify('claude-code.rejectProposedDiff')<CR>]], "v", {desc = "Reject suggestion"})

-- =====================================================
-- MISCELLANEOUS
-- =====================================================

-- Focus and UI
mapKey(
	"<leader>w",
	[[<Cmd>call VSCodeNotify('workbench.action.focusActiveEditorGroup')<CR>]],
	"n",
	{ desc = "Focus active editor group" }
)
mapKey("<leader>m", [[<Cmd>call VSCodeNotify('editor.action.toggleMinimap')<CR>]], "n", { desc = "Toggle minimap" })

-- Markdown
mapKey("<leader>mp", [[<Cmd>call VSCodeNotify('markdown.showPreviewToSide')<CR>]], "n", { desc = "Markdown preview" })

-- =====================================================
-- Extension INTEGRATIONS
-- =====================================================
--
-- Git integration
mapKey("<leader>gl", [[<Cmd>call VSCodeNotify('lazygit.openLazygit')<CR>]], "n", { desc = "Open LazyGit" })

mapKey("<leader>gg", [[<Cmd>call VSCodeNotify('fugitive.open')<CR>]], "n", { desc = "Open fugitive" })

-- mapKey("<leader>gi", [[<Cmd>call VSCodeNotify('gitlens.showCommitDetailsView')<CR>]], "n", { desc = "Open InspectView" })
-- mapKey("<leader>gl", [[<Cmd>call VSCodeNotify('workbench.view.extension.gitlensPanel')<CR>]], "n", { desc = "Open InspectView" })

-- Oil (file explorer)
mapKey("<leader>o", [[<Cmd>call VSCodeNotify('oil-code.open')<CR>]], "n", { desc = "Open oil" })

-- which key
mapKey("<leader><leader>", [[<Cmd>call VSCodeNotify('whichkey.show')<CR>]], "n", { desc = "Show which-key" })
