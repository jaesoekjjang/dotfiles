package main

import (
	"strings"
	"testing"

	"github.com/charmbracelet/x/ansi"
)

func TestSearchCursorUsesDisplayCells(t *testing.T) {
	m := ready()
	m.search.SetValue("한글ab")
	m.search.SetCursor(2)
	v := m.View()
	if v.Cursor == nil || v.Cursor.Position.X != 1+ansi.StringWidth(m.search.Prompt)+4 || v.Cursor.Position.Y != 0 {
		t.Fatalf("cursor does not follow wide Korean characters: %+v", v.Cursor)
	}
	assertCaretAt(t, m, "a")
	// Keep the caret correct after the input scrolls horizontally.
	m.search.SetValue(strings.Repeat("한글", 40) + "Z")
	m.search.CursorEnd()
	m.search.SetCursor(80)
	assertCaretAt(t, m, "Z")
	m.search.SetCursor(0)
	assertCaretAt(t, m, "한")
}

func TestModalCursorFollowsInputPlacement(t *testing.T) {
	for _, kind := range []string{"send", "rename", "create-session", "create-workspace", "create-pane"} {
		t.Run(kind, func(t *testing.T) {
			m := composer()
			m.openModal(kind, m.rows[0])
			m.prompt.SetValue("한글Z")
			m.prompt.SetCursor(2)
			assertCaretAt(t, m, "Z")
			m.width = 60
			m.height = 30
			m.resize()
			assertCaretAt(t, m, "Z")
		})
	}
	m := ready()
	m.openModal("close", m.rows[0])
	if m.View().Cursor != nil {
		t.Fatal("confirmation has no text input caret")
	}
}

func TestFolderEditorUsesNativeCursor(t *testing.T) {
	m := ready()
	pressCreate(m)
	m.Update(ctrl('l'))
	m.folderInput.SetValue("한글Z")
	m.folderInput.SetCursor(2)
	assertCaretAt(t, m, "Z")
}

func assertCaretAt(t *testing.T, m *model, want string) {
	t.Helper()
	v := m.View()
	if v.Cursor == nil {
		t.Fatal("missing native input cursor")
	}
	lines := strings.Split(ansi.Strip(v.Content), "\n")
	y, x := v.Cursor.Position.Y, v.Cursor.Position.X
	if y >= len(lines) {
		t.Fatalf("cursor outside content: %+v", v.Cursor)
	}
	if tail := ansi.TruncateLeft(lines[y], x, ""); !strings.HasPrefix(tail, want) {
		t.Fatalf("caret (%d,%d) points at %q, want %q; line=%q input=%q", x, y, tail, want, lines[y], ansi.Strip(m.search.View()))
	}
}
