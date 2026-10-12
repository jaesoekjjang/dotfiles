package main

import (
	"os"
	"path/filepath"
	"testing"

	tea "charm.land/bubbletea/v2"
)

func TestFolderCompletionPreservesPathsAndExcludesFiles(t *testing.T) {
	base := t.TempDir()
	for _, name := range []string{"한글 폴더", "한글 다른", ".hidden"} {
		if err := os.Mkdir(filepath.Join(base, name), 0700); err != nil {
			t.Fatal(err)
		}
	}
	os.WriteFile(filepath.Join(base, "한글 파일"), []byte(""), 0600)
	os.Symlink(filepath.Join(base, "한글 폴더"), filepath.Join(base, "한글 링크"))
	choices, err := completeFolders("한글", base)
	if err != nil || len(choices) != 3 {
		t.Fatal(choices, err)
	}
	for _, c := range choices {
		if filepath.IsAbs(c.path) {
			t.Fatal("relative spelling lost", c)
		}
		if info, err := os.Stat(filepath.Join(base, c.path)); err != nil || !info.IsDir() {
			t.Fatal(c, err)
		}
	}
	t.Setenv("HOME", base)
	choices, err = completeFolders("~/.h", base)
	if err != nil || len(choices) != 1 || choices[0].path != "~/.hidden/" {
		t.Fatal(choices, err)
	}
	if _, err := completeFolders("relative", ""); err == nil {
		t.Fatal("unknown base must not fall back to process cwd")
	}
}

func TestCreationFocusAndFolderCompletionKeys(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.prompt.SetValue("new")
	original := m.modal
	m.Update(ctrl('n'))
	if m.creationFocus != 1 || m.prompt.Focused() || m.View().Cursor != nil || m.modal != original {
		t.Fatal("C-n should focus folder without changing kind")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if !m.folderEditing {
		t.Fatal("Enter on folder opens editor")
	}
	base := t.TempDir()
	for _, name := range []string{"한글 a", "한글 b"} {
		os.Mkdir(filepath.Join(base, name), 0700)
	}
	m.creationBase = base
	m.folderInput.SetValue("")
	m.Update(tea.PasteMsg{Content: "한글"})
	if len(m.folderChoices) != 2 {
		t.Fatal(m.folderChoices)
	}
	m.Update(ctrl('n'))
	m.Update(ctrl('n'))
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.folderInput.Value() != "한글 b/" || !m.folderEditing || m.busy {
		t.Fatal("select completion must not apply or create")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.folderEditing || m.creationFolder.Path != filepath.Join(base, "한글 b") || m.creationFocus != 0 {
		t.Fatal("apply folder must return to name")
	}
	if len(m.service.(*fakeController).actions) != 0 {
		t.Fatal("folder selection created an item")
	}
}

func TestProjectSearchNavigationPasteCancelAndStaleLoad(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.Update(ctrl('l'))
	original := m.folderInput.Value()
	m.openProjects() // Inject results rather than invoking external processes.
	stale := m.projectGeneration
	m.Update(projectsMsg{generation: stale, choices: parseProjects("/tmp/a\tanchorbase / docs\tmain\n/tmp/b\tDotfiles\tmain\n/tmp/b\tduplicate\tmain\n")})
	m.Update(ctrl('n'))
	m.Update(ctrl('p'))
	if m.folderChoiceIndex != 0 {
		t.Fatal("C-n/p should navigate")
	}
	m.Update(tea.PasteMsg{Content: "dot"})
	if len(m.folderChoices) != 1 || m.folderChoices[0].path != "/tmp/b" {
		t.Fatal(m.folderChoices)
	}
	assertCaretAt(t, m, " ")
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.projectOpen || !m.folderEditing || m.folderInput.Value() != "/tmp/b" {
		t.Fatal("project selection must only fill path")
	}
	m.openProjects()
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	m.Update(projectsMsg{generation: stale, choices: []folderChoice{{path: "/stale"}}})
	if m.projectOpen || len(m.folderChoices) > 0 {
		t.Fatal("late result reopened search")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if m.creationFolder.Path != original {
		t.Fatal("cancel must discard chosen path")
	}
}

func TestQuickTypeSwitchPreservesEditingAndFullHeight(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.prompt.SetValue("keep name")
	m.prompt.SetCursor(3)
	folder := m.creationFolder.Path
	original := m.modal
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.modal == original || m.prompt.Value() != "keep name" || m.prompt.Position() != 3 || !m.prompt.Focused() || m.creationFolder.Path != folder {
		t.Fatal("quick toggle must preserve input and caret")
	}
	m.Update(ctrl('l'))
	m.folderInput.SetValue("~/draft")
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab, Mod: tea.ModShift})
	if m.modal != original || !m.prompt.Focused() {
		t.Fatal("Shift-Tab must also toggle kind")
	}
	m.Update(ctrl('p'))
	if m.creationFocus != 2 {
		t.Fatal("C-p must move to previous field")
	}
	m.Update(ctrl('n'))
	if m.creationFocus != 0 || !m.prompt.Focused() {
		t.Fatal("C-n must restore name focus")
	}
	m.height = 60
	if m.dimensions().leftH < 50 {
		t.Fatal("form must use available screen height")
	}
}

func TestAutomaticSuggestionsDoNotHijackTypedDirectory(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.Update(ctrl('l'))
	base := t.TempDir()
	os.Mkdir(filepath.Join(base, "child"), 0700)
	m.folderInput.SetValue("")
	m.Update(tea.PasteMsg{Content: base + "/"})
	if len(m.folderChoices) != 1 || m.folderChoiceIndex != -1 {
		t.Fatal("suggestions should appear without selecting a child")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.folderEditing || m.creationFolder.Path != base {
		t.Fatal("Enter must apply the typed parent, not its suggested child")
	}
	m.Update(ctrl('l'))
	m.folderInput.SetValue(base + "/")
	m.folderInput.CursorEnd()
	m.Update(tea.KeyPressMsg{Code: 'c', Text: "c"})
	if len(m.folderChoices) != 1 {
		t.Fatal("typing must refresh candidates")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.folderInput.Value() != filepath.Join(base, "child")+"/" || !m.folderEditing {
		t.Fatal("Tab should complete without applying")
	}
}

func TestFolderCompletionSmartcase(t *testing.T) {
	base := filepath.Join(t.TempDir(), "UpperParent")
	for _, name := range []string{"Dotfiles", "docs", "École"} {
		if err := os.MkdirAll(filepath.Join(base, name), 0700); err != nil {
			t.Fatal(err)
		}
	}
	for _, tc := range []struct {
		query string
		want  int
	}{
		{"d", 2}, {"D", 1}, {"dot", 1}, {"DOT", 0}, {"é", 1}, {"É", 1},
	} {
		choices, err := completeFolders(base+"/"+tc.query, base)
		if err != nil || len(choices) != tc.want {
			t.Fatalf("%s: %v, %v", tc.query, choices, err)
		}
		if tc.query == "dot" && choices[0].path != base+"/Dotfiles/" {
			t.Fatal("completion must preserve actual case", choices)
		}
	}
}
