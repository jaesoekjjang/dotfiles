package main

import (
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
	"strings"
	"testing"
)

func TestSplitPreviewKeepsGeometryAndClipsContent(t *testing.T) {
	panes := []tuios.PreviewPane{
		{ID: "a", Title: "agent", X: 10, Y: 5, Width: 60, Height: 40, Screen: "old\n한글 LEFT", AgentState: "done"},
		{ID: "b", Title: "server", X: 70, Y: 5, Width: 40, Height: 20, Screen: "RIGHT TOP"},
		{ID: "c", Title: "logs", X: 70, Y: 25, Width: 40, Height: 20, Screen: "RIGHT BOTTOM"},
	}
	raw := newPickerStyles(true, nil).splitPreview(panes, "a", 100, 20)
	lines := strings.Split(ansi.Strip(raw), "\n")
	if len(lines) != 20 {
		t.Fatal(len(lines))
	}
	if !strings.Contains(lines[0], "agent") || !strings.Contains(lines[0], "server") || !strings.Contains(lines[10], "logs") {
		t.Fatal(strings.Join(lines, "\n"))
	}
	if !strings.Contains(raw, "LEFT") || !strings.Contains(raw, "RIGHT TOP") || !strings.Contains(raw, "RIGHT BOTTOM") {
		t.Fatal(raw)
	}
	for _, line := range lines {
		if ansi.StringWidth(line) != 100 {
			t.Fatal(ansi.StringWidth(line), line)
		}
	}
	for _, size := range [][2]int{{40, 8}, {9, 3}, {1, 1}} {
		view := newPickerStyles(true, nil).splitPreview(panes, "a", size[0], size[1])
		for _, line := range strings.Split(view, "\n") {
			if ansi.StringWidth(line) != size[0] {
				t.Fatal(size, line)
			}
		}
	}
}
func TestSplitPreviewSanitizesControlsAndKeepsTilesIndependent(t *testing.T) {
	panes := []tuios.PreviewPane{
		{ID: "a", Title: "a", Width: 20, Height: 10, Screen: "\x1b]52;c;payload\a\x1b[2J\x1b[31mRED"},
		{ID: "b", Title: "b", X: 20, Width: 20, Height: 10, Screen: "OTHER"},
	}
	view := newPickerStyles(true, nil).splitPreview(panes, "a", 40, 10)
	if strings.Contains(view, "payload") || strings.Contains(view, "\x1b[2J") || !strings.Contains(view, "RED") || !strings.Contains(view, "OTHER") {
		t.Fatal(view)
	}
}

func TestSplitRefreshCanReturnToSinglePane(t *testing.T) {
	m := ready()
	m.preview.Panes = []tuios.PreviewPane{{ID: "a"}, {ID: "b"}}
	m.Update(layoutRefresh{generation: m.generation, preview: tuios.Preview{Screen: "remaining pane"}})
	if len(m.preview.Panes) != 0 || !strings.Contains(m.viewport.View(), "remaining pane") {
		t.Fatal("single-pane viewport retained stale capture")
	}
	m.Update(layoutRefresh{generation: m.generation - 1, preview: tuios.Preview{Screen: "stale"}})
	if strings.Contains(m.viewport.View(), "stale") {
		t.Fatal("late capture replaced current selection")
	}
}
