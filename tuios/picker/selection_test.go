package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"testing"
)

func TestCloseKeepsNearbySelectionAfterReload(t *testing.T) {
	rows := []tuios.Row{
		{ID: "a", Kind: "session", Label: "project a"},
		{ID: "a1", Parent: "a", Kind: "workspace", Label: "project a1"},
		{ID: "a2", Parent: "a", Kind: "workspace", Label: "project a2"},
		{ID: "b", Kind: "session", Label: "project b"},
		{ID: "b1", Parent: "b", Kind: "workspace", Label: "project b1"},
		{ID: "c", Kind: "session", Label: "project c"},
	}
	for _, tc := range []struct{ remove, want, query string }{
		{"a1", "a2", ""}, {"a2", "a1", ""}, {"b1", "b", ""},
		{"b", "c", ""}, {"c", "b", ""}, {"a", "b", ""},
		{"a1", "a2", "project a"},
	} {
		t.Run(tc.remove+tc.query, func(t *testing.T) {
			f := &fakeController{}
			m := newModel(f, "sessions")
			m.Update(loadedMsg{snapshot: tuios.Snapshot{Rows: rows}})
			for _, r := range rows {
				if r.Parent == "" {
					m.expanded[r.ID] = true
				}
			}
			m.search.SetValue(tc.query)
			m.refilter(tc.remove, false)
			var remaining []tuios.Row
			for _, r := range rows {
				if r.ID != tc.remove && r.Parent != tc.remove {
					remaining = append(remaining, r)
				}
			}
			f.snapshot = &tuios.Snapshot{Rows: remaining}
			m.Update(ctrl('x'))
			_, act := m.Update(key('y'))
			_, reload := m.Update(act())
			m.Update(reload())
			if m.selectedID() != tc.want || m.search.Value() != tc.query {
				t.Fatalf("got %s query %q", m.selectedID(), m.search.Value())
			}
		})
	}
}

func TestNavigationAliasesFoldAndSearchEscape(t *testing.T) {
	m := ready()
	m.Update(ctrl('l'))
	if m.selectedID() != "2" {
		t.Fatal("C-l must jump to next group")
	}
	m.Update(ctrl('h'))
	if m.selectedID() != "1" {
		t.Fatal("C-h must jump to previous group")
	}
	m.Update(ctrl('l'))
	m.Update(ctrl('j'))
	m.Update(ctrl('g'))
	if m.selectedID() != "2" || len(m.visible) != 2 {
		t.Fatal("fold all must retain selected parent")
	}
	m.Update(ctrl('g'))
	if len(m.visible) != 4 {
		t.Fatal("unfold all")
	}
	anchor := m.selectedID()
	m.Update(tea.PasteMsg{Content: "no matches"})
	if len(m.visible) != 0 {
		t.Fatal("query should filter")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if m.search.Value() != "" || m.selectedID() != anchor {
		t.Fatal("Escape must restore pre-search selection")
	}
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Fatal("second Escape must exit")
	}
}
func TestCreationNavigationAndFolderShortcut(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.prompt.SetValue("keep")
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if !m.folderEditing {
		t.Fatal("Tab must focus the folder input directly")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab, Mod: tea.ModShift})
	if m.creationFocus != 0 || !m.prompt.Focused() {
		t.Fatal("Shift-Tab must focus the name")
	}
	m.Update(ctrl('o'))
	if !m.folderEditing {
		t.Fatal("C-o must open folder editor")
	}
	m.folderChoices = []folderChoice{{path: "a"}, {path: "b"}}
	m.folderChoiceIndex = -1
	m.Update(ctrl('j'))
	m.Update(ctrl('j'))
	m.Update(ctrl('k'))
	if m.folderChoiceIndex != 0 {
		t.Fatal("candidate aliases disagree")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if !m.folderEditing || len(m.folderChoices) != 0 {
		t.Fatal("first Escape must dismiss candidates")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if m.folderEditing || m.prompt.Value() != "keep" {
		t.Fatal("second Escape must restore form")
	}
}
