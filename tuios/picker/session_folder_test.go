package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
)

func sessionForm(t *testing.T) *model {
	t.Helper()
	m := newModel(&fakeController{}, "sessions")
	m.Update(loadedMsg{snapshot: tuios.Snapshot{Current: "project", Rows: []tuios.Row{{ID: "project", Kind: "session", Session: "test", Label: "current"}}}})
	pressCreate(m)
	m.Update(ctrl('o'))
	return m
}
func TestSessionFolderStartsInlineAndCurrentFolderNeedsOnlyOneConfirmation(t *testing.T) {
	m := sessionForm(t)
	if !m.folderEditing || m.projectOpen || !m.folderInput.Focused() || m.prompt.Focused() {
		t.Fatal("start directly in unified folder input")
	}
	m.Update(tea.WindowSizeMsg{Width: 110, Height: 30})
	view := ansi.Strip(m.View().Content)
	if !strings.Contains(view, "시작 폴더") || !strings.Contains(view, "새 session") || !strings.Contains(view, "현재 작업 폴더") || strings.Contains(view, "시작 폴더 변경") {
		t.Fatal(view)
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.folderEditing || m.creationFolder.Path != "/tmp" || m.prompt.Value() != "tmp" || !m.prompt.Focused() {
		t.Fatal("folder selection should lead directly to the suggested name")
	}
	f := m.service.(*fakeController)
	if len(f.actions) != 0 {
		t.Fatal("folder selection must not create anything")
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m.Update(cmd())
	if len(f.actions) != 1 || f.actions[0] != "create-session::tmp" || f.folders[0] != "/tmp" {
		t.Fatal(f.actions, f.folders)
	}
}
func TestSessionFolderSearchesWorktreesAndPreservesCustomName(t *testing.T) {
	m := sessionForm(t)
	repo := t.TempDir()
	worktree := t.TempDir()
	m.Update(projectsMsg{generation: m.projectGeneration, choices: []folderChoice{{path: repo, label: "ai-chat · main"}, {path: worktree, label: "ai-chat · feature/login"}}})
	m.Update(tea.PasteMsg{Content: "ai-chat feature/login"})
	if locationPath(m.folderInput.Value()) || len(m.folderChoices) != 1 || m.folderChoices[0].path != worktree {
		t.Fatal(m.folderChoices)
	}
	m.prompt.SetValue("내 작업")
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.folderEditing || m.creationFolder.Path != worktree || m.prompt.Value() != "내 작업" {
		t.Fatal("select worktree path directly without replacing custom name")
	}
	m.Update(ctrl('o'))
	m.Update(ctrl('u'))
	m.Update(tea.PasteMsg{Content: "main"})
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.prompt.Value() != "내 작업" || m.creationFolder.Path != repo {
		t.Fatal("name survives folder changes")
	}
}
func TestSessionFolderCompletesNonProjectPathsAndNeverHijacksParent(t *testing.T) {
	m := sessionForm(t)
	base := t.TempDir()
	child := filepath.Join(base, "한글 폴더")
	os.Mkdir(child, 0700)
	m.Update(tea.PasteMsg{Content: base + "/"})
	if len(m.folderChoices) != 1 || m.folderChoiceIndex != -1 {
		t.Fatal(m.folderChoices)
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.creationFolder.Path != base || m.folderEditing {
		t.Fatal("typed parent wins over child suggestions")
	}
	m.Update(ctrl('o'))
	m.Update(ctrl('u'))
	m.Update(tea.PasteMsg{Content: base + "/한"})
	m.Update(ctrl('l'))
	if m.folderInput.Value() != child+"/" || !m.folderEditing {
		t.Fatal("C-l completes a directory without creating or accepting")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.creationFolder.Path != child || m.folderEditing {
		t.Fatal("Enter accepts the completed non-project folder")
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	cmd()
	if m.service.(*fakeController).folders[0] != child {
		t.Fatal("displayed directory must be the created session's cwd")
	}
}
func TestSessionFolderErrorRetryCancelAndLateResults(t *testing.T) {
	m := sessionForm(t)
	original := m.creationFolder.Path
	m.Update(projectsMsg{generation: m.projectGeneration, err: fmt.Errorf("offline")})
	if m.status == "" || !m.folderEditing {
		t.Fatal("lookup failure must leave the same input usable")
	}
	m.Update(tea.PasteMsg{Content: "/definitely-missing-session-folder"})
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if !m.folderEditing || m.status == "" || m.creationFolder.Path != original {
		t.Fatal("invalid paths cannot silently change the destination")
	}
	stale := m.projectGeneration
	m.Update(tea.KeyPressMsg{Code: tea.KeyF5})
	m.Update(projectsMsg{generation: stale, choices: []folderChoice{{path: "/stale", label: "stale"}}})
	if len(m.projects) != 0 {
		t.Fatal("outdated lookup must not replace current results")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	m.Update(projectsMsg{generation: m.projectGeneration, choices: []folderChoice{{path: "/stale", label: "stale"}}})
	if m.modal != "" || m.folderEditing || !m.search.Focused() || len(m.service.(*fakeController).actions) != 0 {
		t.Fatal("Escape cancels the form and late results cannot reopen it")
	}
}
func TestSessionFormCaretAndNarrowScreen(t *testing.T) {
	m := sessionForm(t)
	for _, size := range [][2]int{{120, 35}, {80, 24}, {40, 20}} {
		m.Update(tea.WindowSizeMsg{Width: size[0], Height: size[1]})
		m.folderInput.SetValue("한글Z")
		m.folderInput.SetCursor(2)
		m.refreshSessionFolders()
		assertCaretAt(t, m, "Z")
		m.Update(tea.KeyPressMsg{Code: tea.KeyEnter}) // unmatched query does not leave the field
		lines := strings.Split(ansi.Strip(m.View().Content), "\n")
		if len(lines) > size[1] {
			t.Fatal(size, lines)
		}
		for _, line := range lines {
			if ansi.StringWidth(line) > size[0] {
				t.Fatal(size, line)
			}
		}
	}
	m.folderInput.SetValue("/tmp")
	m.refreshSessionFolders()
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m.prompt.SetValue("한글Z")
	m.prompt.SetCursor(2)
	assertCaretAt(t, m, "Z")
}

func TestSessionFormNameFirstAndShortcutRoles(t *testing.T) {
	m := sessionForm(t)
	m.prompt.SetValue("my-session")
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.folderEditing || !m.prompt.Focused() {
		t.Fatal("Tab moves to the name field")
	}
	lines, folder, name := m.sessionCreationLines(100, 24)
	if name >= folder || !strings.Contains(ansi.Strip(lines[name]), "my-session") {
		t.Fatal("name must precede folder", lines)
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab, Mod: tea.ModShift})
	if !m.folderEditing {
		t.Fatal("Shift-Tab focuses folder")
	}
	m.folderInput.SetValue("draft-query")
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.folderInput.Value() != "draft-query" {
		t.Fatal("field movement preserves query")
	}
	folderBefore := m.creationFolder.Path
	m.Update(tea.KeyPressMsg{Code: ']', Text: "]"})
	if m.modal != "create-workspace" || m.folderEditing || m.prompt.Value() != "my-session" || m.creationFolder.Path != folderBefore {
		t.Fatal("] only switches type")
	}
	m.Update(tea.KeyPressMsg{Code: '[', Text: "["})
	if !m.sessionCreation() || m.folderEditing || !m.prompt.Focused() {
		t.Fatal("[ restores session type")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	m.folderInput.Reset()
	m.Update(projectsMsg{generation: m.projectGeneration, choices: []folderChoice{{path: "/tmp", label: "one"}, {path: "/var", label: "two"}}})
	index := m.folderChoiceIndex
	m.Update(ctrl('n'))
	if !m.folderEditing || m.folderChoiceIndex == index {
		t.Fatal("C-n moves candidates, never fields")
	}
	m.Update(ctrl('p'))
	if m.folderChoiceIndex != index || !m.folderInput.Focused() {
		t.Fatal("C-p returns to previous candidate")
	}
}
func TestSessionCandidateListShowsBoundsAndScrollPosition(t *testing.T) {
	m := sessionForm(t)
	var choices []folderChoice
	for i := 0; i < 30; i++ {
		choices = append(choices, folderChoice{path: fmt.Sprintf("/tmp/%d", i), label: fmt.Sprintf("project-%02d", i)})
	}
	m.Update(projectsMsg{generation: m.projectGeneration, choices: choices})
	m.folderInput.SetValue("project")
	m.refreshSessionFolders()
	m.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	for range 20 {
		m.Update(ctrl('j'))
	}
	view := ansi.Strip(m.View().Content)
	for _, text := range []string{"이름", "후보", "21 / 30", "↑ 더 있음", "↓ 더 있음", "후보 경로"} {
		if !strings.Contains(view, text) {
			t.Fatalf("missing %q: %s", text, view)
		}
	}
	if strings.Index(view, "이름") > strings.Index(view, "시작 폴더") {
		t.Fatal("name must precede folder")
	}
}

func TestSessionCandidateListUsesAvailableHeight(t *testing.T) {
	m := sessionForm(t)
	for i := 0; i < 100; i++ {
		m.projects = append(m.projects, folderChoice{path: fmt.Sprintf("/tmp/%d", i), label: fmt.Sprintf("project-%03d", i)})
	}
	m.folderInput.SetValue("project")
	m.refreshSessionFolders()
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 60})
	view := ansi.Strip(m.View().Content)
	if strings.Count(view, "project-") < 35 {
		t.Fatal("candidate list must use available height", view)
	}
	if !strings.Contains(view, "↓ 더 있음") {
		t.Fatal("hidden candidates need a scroll indicator")
	}
}

func TestSessionShortFolderQueryDoesNotShowFalseTruncation(t *testing.T) {
	m := sessionForm(t)
	m.Update(tea.WindowSizeMsg{Width: 120, Height: 35})
	m.folderInput.SetValue("anchorbase")
	lines, folder, _ := m.sessionCreationLines(m.dimensions().leftW, m.dimensions().leftH-3)
	if ansi.StringWidth(lines[folder]) > m.dimensions().leftW-4 {
		t.Fatal("input width must include the Korean prompt", ansi.Strip(lines[folder]))
	}
}

func TestSessionPendingFolderQueryCannotCreateInPreviousDirectory(t *testing.T) {
	m := sessionForm(t)
	m.prompt.SetValue("new-session")
	m.Update(tea.PasteMsg{Content: "another-project"})
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if !m.folderEditing || m.status == "" || len(m.service.(*fakeController).actions) != 0 {
		t.Fatal("unconfirmed folder changes must not create in the old directory")
	}
}

func TestSessionFolderConfirmationCollapsesCandidates(t *testing.T) {
	m := sessionForm(t)
	m.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	view := ansi.Strip(m.View().Content)
	if strings.Contains(view, "후보") || !strings.Contains(view, "세션 만들기 · Enter") || !strings.Contains(view, "시작 폴더  /tmp") {
		t.Fatal(view)
	}
	m.Update(ctrl('o'))
	if !strings.Contains(ansi.Strip(m.View().Content), "후보") {
		t.Fatal("editing must reopen candidates")
	}
}
func TestSessionFolderQuickCreateAndInvalidPath(t *testing.T) {
	m := sessionForm(t)
	m.prompt.SetValue("custom-name")
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter, Mod: tea.ModCtrl})
	if cmd == nil {
		t.Fatal("quick create must return create command")
	}
	cmd()
	f := m.service.(*fakeController)
	if len(f.actions) != 1 || f.actions[0] != "create-session::custom-name" || f.folders[0] != "/tmp" {
		t.Fatal(f.actions, f.folders)
	}
	m = sessionForm(t)
	m.Update(tea.PasteMsg{Content: "/definitely-missing-session-folder"})
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter, Mod: tea.ModCtrl})
	if !m.folderEditing || len(m.service.(*fakeController).actions) != 0 || m.status == "" {
		t.Fatal("invalid quick create must remain editable")
	}
}
