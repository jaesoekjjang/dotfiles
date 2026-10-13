package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"errors"
	"github.com/charmbracelet/x/ansi"
	"strings"
	"testing"
)

func TestCloseDialogShowsTargetWithoutSearchOrDuplicateHelp(t *testing.T) {
	for _, standalone := range []bool{true, false} {
		m := ready()
		m.standalone = standalone
		m.modal = "close"
		m.modalRow = tuios.Row{Kind: "workspace", Number: 2, Label: "", Panes: 2}
		m.search.SetValue("old query")
		m.Update(tea.WindowSizeMsg{Width: 110, Height: 25})
		view := ansi.Strip(m.View().Content)
		for _, bad := range []string{"찾기", "old query", "0/0", "Workspace 2 · 2", "Workspace preview"} {
			if strings.Contains(view, bad) {
				t.Fatal(bad, view)
			}
		}
		for _, want := range []string{"Workspace 2", "pane 2개", "y 종료"} {
			if !strings.Contains(view, want) {
				t.Fatal(want, view)
			}
		}
		if strings.Count(view, "y 종료") != 1 || m.View().Cursor != nil {
			t.Fatal(view)
		}
	}
}

func TestStandaloneCloseSuccessExitsAndFailureKeepsTarget(t *testing.T) {
	m := ready()
	m.standalone = true
	m.modal = "close"
	m.modalRow = tuios.Row{Kind: "pane", Label: "editor"}
	m.Update(key('y'))
	m.Update(actionMsg{err: errors.New("종료 실패")})
	view := ansi.Strip(m.View().Content)
	if !strings.Contains(view, "editor") || !strings.Contains(view, "종료 실패") || strings.Contains(view, "찾기") {
		t.Fatal(view)
	}
	_, cmd := m.Update(actionMsg{result: tuios.ActionResult{}})
	if _, ok := cmd().(tea.QuitMsg); !ok {
		t.Fatal("successful pane close must exit")
	}
}

func TestModalHeadersDoNotShowSearch(t *testing.T) {
	for _, modal := range []string{"rename", "send"} {
		m := ready()
		m.openModal(modal, tuios.Row{Label: "editor"})
		view := ansi.Strip(m.View().Content)
		if strings.Contains(view, "찾기") || strings.Contains(view, "2/4") {
			t.Fatal(view)
		}
	}
}

func TestPopupConfirmationUsesHostBorderAndFitsCompactWindow(t *testing.T) {
	for _, kind := range []string{"pane", "workspace", "session"} {
		m := ready()
		m.standalone = true
		m.modal = "close"
		m.modalRow = tuios.Row{Kind: kind, Label: "확인: X로 세션 닫기 동작 | control-plane-docs", Number: 2, Panes: 2}
		m.Update(tea.WindowSizeMsg{Width: 82, Height: 9})
		view := ansi.Strip(m.View().Content)
		if strings.ContainsAny(view, "╭╮╰╯│") {
			t.Fatal("duplicate popup border", view)
		}
		if len(strings.Split(view, "\n")) > 9 {
			t.Fatal("dialog overflows", view)
		}
		for _, line := range strings.Split(view, "\n") {
			if ansi.StringWidth(line) > 82 {
				t.Fatal("line overflows", line)
			}
		}
		if !strings.Contains(view, "y 종료") {
			t.Fatal(view)
		}
	}
}
