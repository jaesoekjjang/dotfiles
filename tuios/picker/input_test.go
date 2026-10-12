package main

import (
	"fmt"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
)

func composer() *model {
	m := ready()
	m.rows[0].Session = "source"
	m.refilter("1", false)
	m.previewLoading = false
	m.preview = tuios.Preview{PaneID: "editor", Workspace: 1, Location: "Project › 1 dev", Title: "Editor"}
	return m
}

func TestSendInputPinsPreviewAndPreservesPicker(t *testing.T) {
	m := composer()
	m.search.SetValue("dev")
	m.refilter("1", false)
	selected := m.selectedID()
	m.Update(ctrl('s'))
	if m.modal != "send" || m.modalRow.ID != "pane::editor" || m.modalRow.Session != "source" || m.modalRow.Number != 1 {
		t.Fatalf("wrong input target: %q %+v", m.modal, m.modalRow)
	}
	if !strings.Contains(m.listView(60, 15), "Project › 1 dev") {
		t.Fatal("composer must show its destination")
	}
	// A later preview cannot retarget text already being composed.
	m.preview.PaneID = "other"
	m.prompt.SetValue("  한글 '$(literal)'  ")
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if cmd == nil || !m.busy {
		t.Fatal("Enter should start a send")
	}
	_, duplicate := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if duplicate != nil {
		t.Fatal("repeated Enter must not send twice")
	}
	m.Update(cmd())
	f := m.service.(*fakeController)
	if len(f.actions) != 1 || f.actions[0] != "send:pane::editor:  한글 '$(literal)'  " {
		t.Fatalf("unexpected send: %v", f.actions)
	}
	if m.modal != "" || m.selectedID() != selected || m.search.Value() != "dev" || !strings.Contains(m.status, "입력 전송됨") {
		t.Fatal("send should return to the same picker selection and query")
	}
}

func TestSendCancelEmptyAndFailure(t *testing.T) {
	m := composer()
	m.Update(ctrl('s'))
	m.prompt.SetValue("   ")
	_, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	if cmd != nil || m.busy {
		t.Fatal("empty text must not send")
	}
	m.prompt.SetValue("keep this text")
	m.busy = true
	m.Update(actionMsg{err: fmt.Errorf("pane is gone")})
	if m.modal != "send" || m.prompt.Value() != "keep this text" || m.busy {
		t.Fatal("failure must keep the text visible without retrying")
	}
	m.Update(tea.KeyPressMsg{Code: tea.KeyEscape})
	if m.modal != "" || len(m.service.(*fakeController).actions) != 0 {
		t.Fatal("cancel must not send")
	}
}

func TestSendRequiresVisibleResolvedPreview(t *testing.T) {
	for _, state := range []string{"loading", "empty", "hidden"} {
		m := composer()
		switch state {
		case "loading":
			m.previewLoading = true
		case "empty":
			m.preview.PaneID = ""
		case "hidden":
			m.showPreview = false
		}
		m.Update(ctrl('s'))
		if m.modal != "" {
			t.Fatalf("opened composer with %s preview", state)
		}
	}
}
