package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"testing"
)

func TestPaneCycleTargetsActionsAndSurvivesRefresh(t *testing.T) {
	m := ready()
	m.previewLoading = false
	original := tuios.Preview{PaneID: "a", Workspace: 1, Panes: []tuios.PreviewPane{
		{ID: "a", Title: "agent", Command: "codex", Screen: "A"},
		{ID: "b", Title: "editor", Command: "nvim", Screen: "B"},
	}}
	m.preview = original
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.preview.PaneID != "b" || m.selectedID() != "1" || m.preview.Screen != "B" {
		t.Fatalf("selection: %+v", m.preview)
	}
	f := m.service.(*fakeController)
	if len(f.actions) != 0 {
		t.Fatal("cycling changed live focus")
	}
	m.Update(layoutRefresh{generation: m.generation, preview: original})
	if m.preview.PaneID != "b" {
		t.Fatal("refresh lost selection")
	}
	m.Update(ctrl('s'))
	if m.modalRow.ID != "pane::b" || m.modal != "send" {
		t.Fatalf("send target: %+v", m.modalRow)
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	cmd()
	if f.actions[0] != "enter:pane::b:" {
		t.Fatal(f.actions)
	}
	m.busy = false
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.preview.PaneID != "a" {
		t.Fatal("forward wrap")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab, Mod: tea.ModShift})
	if m.preview.PaneID != "b" {
		t.Fatal("reverse wrap")
	}
	// A removed pane falls back to the fresh backend target.
	original.Panes = original.Panes[:1]
	m.Update(layoutRefresh{generation: m.generation, preview: original})
	if m.preview.PaneID != "a" {
		t.Fatal("removed pane retained")
	}
}

func TestPaneCycleUnavailableDoesNotFoldOrEditQuery(t *testing.T) {
	m := ready()
	m.search.SetValue("dev")
	m.refilter("1", false)
	for _, loading := range []bool{true, false} {
		m.previewLoading = loading
		m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
		if m.search.Value() != "dev" || !m.expanded["1"] {
			t.Fatal("Tab changed list")
		}
	}
	m.Update(ctrl('o'))
	if m.expanded["1"] {
		t.Fatal("C-o must fold")
	}
}
