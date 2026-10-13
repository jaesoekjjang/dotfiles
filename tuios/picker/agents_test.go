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

func TestMoveEnterAndControlEnterAreDistinct(t *testing.T) {
	for _, tc := range []struct {
		mod    tea.KeyMod
		action string
	}{
		{0, "move"}, {tea.ModCtrl, "move-stay"},
	} {
		f := &fakeController{}
		m := newModel(f, "move-pane")
		m.Update(loadedMsg{snapshot: tuios.Snapshot{Rows: []tuios.Row{{ID: "move:new", Kind: "new-workspace", Label: "+ 새 workspace"}}, Current: "move:new"}})
		_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter, Mod: tc.mod})
		if cmd == nil {
			t.Fatal("key did not dispatch move")
		}
		m.Update(cmd())
		if len(f.actions) != 1 || f.actions[0] != tc.action+":move:new:" {
			t.Fatal(f.actions)
		}
	}
}

func TestSessionStartsExpandedAndSuppressesOnlyVisibleDuplicates(t *testing.T) {
	m := newModel(&fakeController{}, "sessions")
	parent := tuios.Row{ID: "s", Kind: "session", Label: "project", Current: true, Agents: tuios.AgentCounts{Working: 1}}
	child := tuios.Row{ID: "w", Parent: "s", Kind: "workspace", Label: "이름 없음", Number: 1, Current: true, Agents: parent.Agents}
	m.Update(loadedMsg{snapshot: tuios.Snapshot{Rows: []tuios.Row{parent, child}, Current: "s"}})
	if len(m.visible) != 2 || !m.expanded["s"] {
		t.Fatal("sessions must initially be expanded")
	}
	m.Update(ctrl('o'))
	if !strings.Contains(ansi.Strip(m.rowView(parent, 80, false)), "current") {
		t.Fatal("collapsed summary missing")
	}
	m.Update(ctrl('o'))
	parentLine := ansi.Strip(m.rowView(parent, 80, false))
	childLine := ansi.Strip(m.rowView(child, 80, false))
	if strings.Contains(parentLine, "작업 중") || strings.Contains(parentLine, "current") {
		t.Fatal(parentLine)
	}
	if !strings.Contains(childLine, "1  —") || !strings.Contains(childLine, "current") || strings.Contains(childLine, "workspace") {
		t.Fatal(childLine)
	}
	m.search.SetValue("project")
	if !strings.Contains(ansi.Strip(m.rowView(parent, 80, false)), "작업 중") {
		t.Fatal("search must preserve aggregate")
	}
}
