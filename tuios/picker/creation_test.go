package main

import (
	"fmt"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
)

func TestCreationTypeAndParentFromFilteredChild(t *testing.T) {
	for _, mode := range []string{"sessions", "workspaces"} {
		t.Run(mode, func(t *testing.T) {
			rootKind, childKind := "session", "workspace"
			if mode == "workspaces" {
				rootKind, childKind = "workspace", "pane"
			}
			rows := []tuios.Row{
				{ID: "parent", Kind: rootKind, Label: "project", Session: "destination", Number: 2},
				{ID: "child", Parent: "parent", Kind: childKind, Label: "logs", Session: "destination", Number: 2},
			}
			m := newModel(&fakeController{}, mode)
			m.Update(loadedMsg{snapshot: tuios.Snapshot{Rows: rows}})
			m.search.SetValue("logs")
			m.refilter("child", false)
			m.Update(ctrl('a'))
			if m.modal != "create-"+childKind || m.modalRow.ID != "parent" || m.creationChild.ID != "parent" {
				t.Fatal("default to adding alongside selected child under its actual parent", m.modal, m.modalRow, m.creationChild)
			}
			m.prompt.SetValue("review notes")
			if m.modal != "create-"+childKind || m.modalRow.ID != "parent" || m.prompt.Value() != "review notes" {
				t.Fatal("switch without losing name or parent")
			}
			view := ansi.Strip(m.View().Content)
			if !strings.Contains(view, "project") || !strings.Contains(view, "Tab 종류 전환") || strings.Contains(view, "Preview") {
				t.Fatal(view)
			}
			m.Update(tea.KeyPressMsg{Code: tea.KeyTab, Mod: tea.ModShift})
			if m.modal != "create-"+rootKind || m.modalRow.ID != "" {
				t.Fatal("switch back to default")
			}
			m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
			if m.search.Value() != "logs" || m.selectedID() != "child" || !m.search.Focused() {
				t.Fatal("cancel must preserve search and selection")
			}
		})
	}
}

func TestCreationSequencePinsParentExpandsAndSelectsNewChild(t *testing.T) {
	m := ready()
	f := m.service.(*fakeController)
	m.expanded["1"] = false
	m.refilter("1", false)
	m.Update(ctrl('a'))
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	for i, name := range []string{"server", "logs"} {
		id := fmt.Sprintf("pane:1:new%d", i)
		f.createdID = id
		f.snapshot = &tuios.Snapshot{Rows: append(sample().Rows, tuios.Row{ID: id, Parent: "1", Kind: "pane", Label: name})}
		m.prompt.SetValue(name)
		_, create := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
		m.Update(tea.KeyPressMsg{Code: tea.KeyEnter}) // No duplicate while creation is in flight.
		_, reload := m.Update(create())
		if m.modal != "" || !m.search.Focused() || !m.busy {
			t.Fatal("return to list and wait for newly created row")
		}
		m.Update(reload())
		if m.selectedID() != id || !m.expanded["1"] || m.busy {
			t.Fatal("reveal and select new child", m.selectedID())
		}
		m.Update(ctrl('a'))
		if m.modal != "create-pane" || m.modalRow.ID != "1" {
			t.Fatal("next creation must default to the selected pane's level")
		}
	}
	if strings.Join(f.actions, ",") != "create-pane:1:server,create-pane:1:logs" {
		t.Fatal(f.actions)
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	m.Update(ctrl('a'))
	if m.modal != "create-pane" || m.modalRow.ID != "1" {
		t.Fatal("new form must resolve selected child's parent")
	}
}

func TestCreationFailureRetainsInputAndPartialSuccessStopsSequence(t *testing.T) {
	m := ready()
	m.Update(ctrl('a'))
	m.prompt.SetValue("review")
	m.Update(ctrl('a'))
	if len(m.service.(*fakeController).actions) != 0 || m.prompt.Position() != 0 {
		t.Fatal("Ctrl-a in the form must move to line start, not create")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m.Update(actionMsg{err: fmt.Errorf("workspace full")})
	if m.modal != "create-workspace" || m.prompt.Value() != "review" || !m.prompt.Focused() || m.busy || m.status != "workspace full" {
		t.Fatal("failure must retain editable form")
	}
	_, reload := m.Update(actionMsg{result: tuios.ActionResult{Selected: "2", Warning: "created, rename failed"}})
	m.Update(reload())
	if m.modal != "" || m.status != "created, rename failed" || m.selectedID() != "2" || !m.search.Focused() {
		t.Fatal("partial success must stop repeat and reveal result", m.status)
	}
}

func TestCreationWithoutSelectionCannotSwitchToChild(t *testing.T) {
	m := ready()
	m.search.SetValue("no matching item")
	m.refilter("", true)
	m.Update(ctrl('a'))
	m.prompt.SetValue("new")
	m.Update(tea.KeyPressMsg{Code: tea.KeyTab})
	if m.modal != "create-workspace" || m.modalRow.ID != "" || m.prompt.Value() != "new" || m.status == "" {
		t.Fatal("root creation remains possible, child creation needs selection")
	}
}

func TestCreationFormFitsNarrowScreens(t *testing.T) {
	m := ready()
	for _, size := range [][2]int{{120, 35}, {80, 24}, {40, 20}} {
		m.Update(tea.WindowSizeMsg{Width: size[0], Height: size[1]})
		m.Update(ctrl('a'))
		view := m.View().Content
		if len(strings.Split(view, "\n")) > size[1] {
			t.Fatal(size, view)
		}
		for _, line := range strings.Split(view, "\n") {
			if ansi.StringWidth(line) > size[0] {
				t.Fatal(size, line)
			}
		}
		m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	}
}
