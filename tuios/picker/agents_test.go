package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
	"strings"
	"testing"
)

func TestAgentRefreshPreservesSearchSelectionOrderAndBusy(t *testing.T) {
	m := ready()
	id := m.selectedID()
	rows := append([]tuios.Row(nil), m.rows...)
	rows[0].Agents = tuios.AgentCounts{Done: 1, Working: 2}
	m.Update(agentRefresh{snapshot: tuios.Snapshot{Rows: rows}})
	if m.selectedID() != id || m.rows[0].ID != rows[0].ID {
		t.Fatal("refresh moved selection")
	}
	view := ansi.Strip(m.View().Content)
	if !strings.Contains(view, "완료 1") || !strings.Contains(view, "작업 중 2") {
		t.Fatal(view)
	}
	m.busy = true
	rows[0].Agents = tuios.AgentCounts{}
	m.Update(agentRefresh{snapshot: tuios.Snapshot{Rows: rows}})
	if !m.busy || m.rows[0].Agents.Done != 1 {
		t.Fatal("background load interrupted action")
	}
}
func TestMovePickerOnlyMovesAndKeepsNewDefault(t *testing.T) {
	f := &fakeController{}
	m := newModel(f, "move-pane")
	rows := []tuios.Row{{ID: "move:new", Kind: "new-workspace", Label: "+ 새 workspace"}, {ID: "2", Kind: "workspace", Label: "logs", Number: 2}}
	m.Update(loadedMsg{snapshot: tuios.Snapshot{Rows: rows, Current: "move:new"}})
	if m.selectedID() != "move:new" || m.showPreview {
		t.Fatal("wrong default")
	}
	m.Update(ctrl('a'))
	m.Update(ctrl('x'))
	m.Update(ctrl('r'))
	if m.modal != "" || len(f.actions) != 0 {
		t.Fatal("move picker exposed destructive unrelated actions")
	}
	m.search.Reset()
	m.refilter("move:new", false)
	m.Update(ctrl('n'))
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m.Update(cmd())
	if len(f.actions) != 1 || f.actions[0] != "move:2:" {
		t.Fatal(f.actions)
	}
}
