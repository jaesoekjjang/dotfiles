package main

import (
	"fmt"
	"reflect"
	"slices"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
)

type fakeController struct {
	actions   []string
	previews  int
	createdID string
	snapshot  *tuios.Snapshot
}

func (f *fakeController) Snapshot(string) (tuios.Snapshot, error) {
	if f.snapshot != nil {
		return *f.snapshot, nil
	}
	return sample(), nil
}
func (f *fakeController) Preview(row tuios.Row) (tuios.Preview, error) {
	f.previews++
	return tuios.Preview{Title: row.ID, Screen: "latest"}, nil
}
func (f *fakeController) Act(action string, row tuios.Row, name string) (tuios.ActionResult, error) {
	f.actions = append(f.actions, action+":"+row.ID+":"+name)
	if strings.HasPrefix(action, "create-") {
		return tuios.ActionResult{Selected: f.createdID}, nil
	}
	return tuios.ActionResult{}, nil
}
func sample() tuios.Snapshot {
	return tuios.Snapshot{Current: "1", Rows: []tuios.Row{
		{ID: "1", Kind: "workspace", Label: "dev", Number: 1, Current: true},
		{ID: "pane:1:a", Parent: "1", Kind: "pane", Label: "editor", Command: "nvim"},
		{ID: "2", Kind: "workspace", Label: "logs", Number: 2},
		{ID: "pane:2:b", Parent: "2", Kind: "pane", Label: "shell", Command: "zsh"},
	}}
}
func ready() *model {
	m := newModel(&fakeController{}, "workspaces")
	m.Update(loadedMsg{snapshot: sample()})
	return m
}
func ctrl(c rune) tea.KeyPressMsg { return tea.KeyPressMsg{Code: c, Mod: tea.ModCtrl} }
func key(c rune) tea.KeyPressMsg  { return tea.KeyPressMsg{Code: c, Text: string(c)} }

func TestTreeNavigationAndWrapping(t *testing.T) {
	m := ready()
	if len(m.visible) != 4 || m.selectedID() != "1" {
		t.Fatal("defaults should expand everything and select current")
	}
	m.Update(ctrl('p'))
	if m.selectedID() != "pane:2:b" {
		t.Fatal("row wrap")
	}
	m.Update(ctrl('j'))
	if m.selectedID() != "1" {
		t.Fatal("group wrap")
	}
	m.Update(ctrl('k'))
	if m.selectedID() != "2" {
		t.Fatal("group backward")
	}
	m.Update(ctrl('n'))
	m.Update(ctrl('o'))
	if m.selectedID() != "2" || m.expanded["2"] {
		t.Fatal("child folds to parent")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if !m.expanded["2"] {
		t.Fatal("tab expands")
	}
	m.Update(ctrl('g'))
	if len(m.visible) != 2 {
		t.Fatal("collapse all")
	}
	m.Update(ctrl('g'))
	if len(m.visible) != 4 {
		t.Fatal("expand all")
	}
}
func TestSessionGroupsAndHiddenMatch(t *testing.T) {
	m := newModel(&fakeController{}, "sessions")
	m.Update(loadedMsg{snapshot: tuios.Snapshot{Current: "waa", Rows: []tuios.Row{
		{ID: "waa", Kind: "session", Label: "anchorbase"}, {ID: "ws:waa:1", Parent: "waa", Kind: "workspace", Label: "control plane", Number: 1},
		{ID: "wbb", Kind: "session", Label: "dotfiles"}, {ID: "ws:wbb:2", Parent: "wbb", Kind: "workspace", Label: "terminal", Number: 2},
	}}})
	m.Update(ctrl('n'))
	m.Update(ctrl('j'))
	if m.selectedID() != "wbb" {
		t.Fatal("session jump")
	}
	m.search.SetValue("control")
	m.refilter("", true)
	m.Update(ctrl('o'))
	if m.search.Value() != "control" || len(m.visible) != 1 || m.expanded["waa"] {
		t.Fatal("session folding must preserve query and searchable workspaces")
	}
	m.Update(ctrl('g'))
	if len(m.visible) != 1 {
		t.Fatal("fold state must not hide workspace search results")
	}
}

func TestSessionWorkspacePathSearchAndContext(t *testing.T) {
	m := newModel(&fakeController{}, "sessions")
	m.Update(loadedMsg{snapshot: tuios.Snapshot{Current: "waa", Rows: []tuios.Row{
		{ID: "waa", Kind: "session", Label: "anchorbase"},
		{ID: "ws:waa:2", Parent: "waa", Kind: "workspace", Label: "terminal", Number: 2, Session: "session-aa", SessionID: "waa"},
		{ID: "wbb", Kind: "session", Label: "dotfiles"},
		{ID: "ws:wbb:2", Parent: "wbb", Kind: "workspace", Label: "terminal", Number: 2, Session: "session-bb", SessionID: "wbb"},
	}}})
	m.Update(ctrl('g'))
	for query, want := range map[string]string{
		"anchorbaseterminal": "ws:waa:2", "anchorbase terminal": "ws:waa:2", "anchor term": "ws:waa:2",
		"dotfilesterminal": "ws:wbb:2", "terminal dotfiles": "ws:wbb:2", "dotfiles 2": "ws:wbb:2",
	} {
		m.search.SetValue(query)
		m.refilter("", true)
		if len(m.visible) != 1 || m.selectedID() != want {
			t.Fatalf("%q: %+v", query, m.visible)
		}
	}
	m.search.SetValue("terminal")
	m.refilter("", true)
	if len(m.visible) != 2 {
		t.Fatal("both terminal workspaces should match")
	}
	view := ansi.Strip(m.View().Content)
	for _, label := range []string{"anchorbase › 2 terminal", "dotfiles › 2 terminal", "2/4"} {
		if !strings.Contains(view, label) {
			t.Fatalf("missing context %q", label)
		}
	}
	m.Update(ctrl('j'))
	if m.selectedID() != "ws:wbb:2" {
		t.Fatal("jump to next matching session workspace")
	}
	m.Update(ctrl('k'))
	if m.selectedID() != "ws:waa:2" {
		t.Fatal("jump back to previous matching session workspace")
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	cmd()
	if got := m.service.(*fakeController).actions; !reflect.DeepEqual(got, []string{"enter:ws:waa:2:"}) {
		t.Fatal(got)
	}
	m.busy = false
	m.search.Reset()
	m.refilter("", true)
	if len(m.visible) != 2 || m.expanded["waa"] || m.expanded["wbb"] {
		t.Fatal("clearing search restores prior folds")
	}
}
func TestSearchTermsRankingAndScope(t *testing.T) {
	for _, tc := range []struct {
		text, query string
		want        bool
	}{
		{"anchor control plane", "acp", true}, {"anchor control plane", "anchor cp", true},
		{"anchor docs", "^anchor !docs", false}, {"anchor control", "^anchor !docs", true},
		{"docs", "!dcs", true}, {"docs", "!'dcs", false},
		{"terminal", "^term", true}, {"terminal", "'ermi", true}, {"terminal", "nal$", true},
		{"terminal", "^terminal$", true}, {"terminal", "Terminal", false}, {"terminal", "docs | term", true},
		{"terminal", "missing", false}, {"한글 작업", "ㅎ", false}, {"한글 작업", "한작", true},
	} {
		t.Run(tc.query, func(t *testing.T) {
			_, ok := matchQuery(tc.text, tc.query)
			if ok != tc.want {
				t.Fatalf("%q %q: %v", tc.text, tc.query, ok)
			}
		})
	}
	m := ready()
	m.Update(key('l'))
	if m.selectedID() != "2" {
		t.Fatal("best match first")
	}
	m.search.SetValue("nvim")
	m.refilter("", true)
	if len(m.visible) != 0 {
		t.Fatal("commands excluded from search")
	}
}
func TestDeleteIsConfirmedAndScrollNeverDeletes(t *testing.T) {
	m := ready()
	f := m.service.(*fakeController)
	var lines []string
	for i := 0; i < 80; i++ {
		lines = append(lines, fmt.Sprintf("line %d", i))
	}
	m.Update(previewMsg{generation: m.generation, preview: tuios.Preview{Screen: strings.Join(lines, "\n")}})
	if !m.viewport.AtBottom() {
		t.Fatal("preview starts at latest output")
	}
	m.Update(ctrl('u'))
	if m.viewport.AtBottom() {
		t.Fatal("half page up")
	}
	m.Update(ctrl('d'))
	if !m.viewport.AtBottom() {
		t.Fatal("half page down")
	}
	if len(f.actions) != 0 {
		t.Fatal("scroll must never delete")
	}
	m.Update(ctrl('x'))
	if m.modal != "close" || len(f.actions) != 0 {
		t.Fatal("confirmation required")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.modal != "" || len(f.actions) != 0 {
		t.Fatal("Enter defaults to cancel")
	}
	m.Update(ctrl('n'))
	m.Update(ctrl('x'))
	_, cmd := m.Update(key('y'))
	m.Update(cmd())
	if len(f.actions) != 1 || f.actions[0] != "close:pane:1:a:" {
		t.Fatalf("selected child target: %v", f.actions)
	}
	m.Update(key('l'))
	if m.search.Value() != "l" || m.selectedID() != "2" {
		t.Fatal("confirmed deletion must restore search input focus")
	}
}
func TestSelectionQueryAndFoldSurviveMutation(t *testing.T) {
	m := ready()
	m.search.SetValue("dev")
	m.refilter("1", false)
	m.Update(ctrl('r'))
	m.prompt.SetValue("development")
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	_, reload := m.Update(cmd())
	m.Update(reload())
	if m.search.Value() != "dev" || m.selectedID() != "1" {
		t.Fatal("rename preserves search and identity")
	}
	m.search.Reset()
	m.refilter("2", false)
	m.Update(ctrl('o'))
	data := sample()
	data.Rows = data.Rows[:2]
	m.Update(loadedMsg{snapshot: data})
	if m.selectedID() != "pane:1:a" {
		t.Fatalf("nearest remaining position: %s", m.selectedID())
	}
}
func TestChildRenamePreservesQuerySelectionAndTree(t *testing.T) {
	for _, kind := range []string{"workspace", "pane"} {
		t.Run(kind, func(t *testing.T) {
			mode, parentKind := "sessions", "session"
			if kind == "pane" {
				mode, parentKind = "workspaces", "workspace"
			}
			data := tuios.Snapshot{Current: "parent", Rows: []tuios.Row{
				{ID: "parent", Kind: parentKind, Label: "project", Current: true},
				{ID: "child", Parent: "parent", Kind: kind, Label: "terminal", Number: 2},
			}}
			f := &fakeController{snapshot: &data}
			m := newModel(f, mode)
			m.Update(loadedMsg{snapshot: data})
			m.search.SetValue("term")
			m.refilter("child", false)
			m.Update(ctrl('r'))
			if m.modal != "rename" || m.modalRow.ID != "child" || m.prompt.Value() != "terminal" {
				t.Fatal("Ctrl-r must edit the selected child's name")
			}
			m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
			if len(f.actions) != 0 || !m.search.Focused() {
				t.Fatal("cancel must restore search without renaming")
			}
			m.Update(ctrl('r'))
			m.prompt.SetValue("terminal 리뷰")
			_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
			msg := cmd()
			data.Rows[1].Label = "terminal 리뷰"
			_, reload := m.Update(msg)
			m.Update(reload())
			if !reflect.DeepEqual(f.actions, []string{"rename:child:terminal 리뷰"}) {
				t.Fatal(f.actions)
			}
			if m.search.Value() != "term" || m.selectedID() != "child" || !m.expanded["parent"] || !m.search.Focused() {
				t.Fatal("rename must preserve the query, child selection, tree and input focus")
			}
			if m.rows[0].Label != "project" || m.visible[0].Label != "terminal 리뷰" {
				t.Fatal("only the child's name should change", m.rows)
			}
		})
	}
}

func TestWorkspaceCreationPromptsForNameAndCanCancel(t *testing.T) {
	m := ready()
	f := m.service.(*fakeController)
	m.Update(ctrl('a'))
	if m.modal != "create-workspace" || m.prompt.Prompt != "새 workspace › " || len(f.actions) != 0 {
		t.Fatal("workspace creation must ask for a name before acting")
	}
	m.prompt.SetValue("   ")
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if m.modal != "" || !m.search.Focused() || len(f.actions) != 0 {
		t.Fatal("empty input cancels creation and restores search")
	}
	m.Update(ctrl('a'))
	m.prompt.SetValue("discard")
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if m.modal != "" || len(f.actions) != 0 {
		t.Fatal("Escape cancels creation")
	}
	m.Update(ctrl('a'))
	m.prompt.SetValue("  review notes  ")
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	cmd()
	if !reflect.DeepEqual(f.actions, []string{"create-workspace::review notes"}) {
		t.Fatal(f.actions)
	}
}

func TestCreatedItemStaysInPickerAndIsSelected(t *testing.T) {
	for _, mode := range []string{"sessions", "workspaces"} {
		t.Run(mode, func(t *testing.T) {
			current, created, kind := "waa", "wcc", "session"
			if mode == "workspaces" {
				current, created, kind = "1", "3", "workspace"
			}
			before := tuios.Snapshot{Current: current, Rows: []tuios.Row{{ID: current, Kind: kind, Label: "old", Current: true}}}
			after := tuios.Snapshot{Current: current, Rows: append(slices.Clone(before.Rows), tuios.Row{ID: created, Kind: kind, Label: "new"})}
			f := &fakeController{createdID: created, snapshot: &after}
			m := newModel(f, mode)
			m.Update(loadedMsg{snapshot: before})
			m.search.SetValue("old")
			m.refilter("", true)
			m.Update(ctrl('a'))
			m.prompt.SetValue("new")
			_, create := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
			result := create().(actionMsg)
			if result.result.Exit {
				t.Fatal("creation must keep the picker open")
			}
			_, reload := m.Update(result)
			if m.search.Value() != "" || !m.busy {
				t.Fatal("clear filter and wait for newly created row")
			}
			m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
			if len(f.actions) != 1 {
				t.Fatal("Enter must not navigate to the old row while loading")
			}
			m.Update(reload())
			if m.selectedID() != created || m.busy || !m.search.Focused() {
				t.Fatal("select created item and restore input")
			}
			if !m.rows[0].Current || m.rows[1].Current {
				t.Fatal("creating does not change current session/workspace")
			}
			_, navigate := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
			navigate()
			if f.actions[1] != "enter:"+created+":" {
				t.Fatal(f.actions)
			}
		})
	}
}

func TestPreviewDebounceStaleResponsesAndToggle(t *testing.T) {
	m := ready()
	f := m.service.(*fakeController)
	old := m.generation
	m.Update(ctrl('n'))
	if _, cmd := m.Update(previewRequest{generation: old}); cmd != nil {
		t.Fatal("obsolete request must not capture")
	}
	m.Update(previewMsg{generation: old, preview: tuios.Preview{Title: "wrong"}})
	if m.preview.Title == "wrong" {
		t.Fatal("stale preview")
	}
	_, cmd := m.Update(previewRequest{generation: m.generation, row: m.visible[m.index]})
	m.Update(cmd())
	if f.previews != 1 || m.preview.Title != "pane:1:a" {
		t.Fatal("selected preview")
	}
	m.Update(ctrl('_'))
	if m.showPreview {
		t.Fatal("legacy Ctrl-/ alias")
	}
	m.Update(ctrl('/'))
	if !m.showPreview {
		t.Fatal("show again")
	}
	if !m.previewLoading {
		t.Fatal("show must refresh once")
	}
}
func TestPasteFiltersAndRequestsPreview(t *testing.T) {
	m := ready()
	m.Update(tea.PasteMsg{Content: "logs"})
	if m.selectedID() != "2" || !m.previewLoading {
		t.Fatal("paste should filter and preview")
	}
}
func TestStandaloneConfirmationDoesNotLoadList(t *testing.T) {
	m := ready()
	m.standalone = true
	m.modal = "close"
	if m.Init() != nil {
		t.Fatal("no unnecessary list load")
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Fatal("cancel standalone closes picker")
	}
}
func TestCapturedControlsAndResponsiveGeometry(t *testing.T) {
	got := screenText("\x1b]0;bad\a\x1b[2J\x1b[31m한글\x1b[0m\nnext")
	if strings.Contains(got, "bad") || strings.Contains(got, "[2J") || !strings.Contains(got, "\x1b[31m한글") {
		t.Fatalf("unsafe preview: %q", got)
	}
	m := ready()
	for _, size := range [][2]int{{197, 55}, {120, 35}, {80, 24}, {60, 25}, {40, 20}} {
		m.Update(tea.WindowSizeMsg{Width: size[0], Height: size[1]})
		view := m.View().Content
		lines := strings.Split(view, "\n")
		if len(lines) > size[1] {
			t.Fatalf("%v: %d lines", size, len(lines))
		}
		for _, line := range lines {
			if ansi.StringWidth(line) > size[0] {
				t.Fatalf("%v: width %d", size, ansi.StringWidth(line))
			}
		}
		if !strings.Contains(ansi.Strip(view), "C-x 종료") {
			t.Fatal("delete key guide")
		}
	}
}
