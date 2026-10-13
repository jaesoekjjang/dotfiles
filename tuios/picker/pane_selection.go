package main

import (
	"fmt"
	"os"
	"strings"

	"dotfiles/tuios-picker/internal/tuios"
)

// Selection only changes the preview target, never the live terminal focus.
func (m *model) selectPreviewPane(id string) {
	for _, p := range m.preview.Panes {
		if p.ID != id {
			continue
		}
		m.preview.PaneID = p.ID
		m.preview.Title = fmt.Sprintf("● %s  [%s]", p.Title, p.Command)
		m.preview.Path = p.Path
		if home, err := os.UserHomeDir(); err == nil && (p.Path == home || strings.HasPrefix(p.Path, home+"/")) {
			m.preview.Path = "~" + strings.TrimPrefix(p.Path, home)
		}
		m.preview.Screen = p.Screen
		m.preview.Current = p.Current
		return
	}
}

func (m *model) cyclePreviewPane(direction int) {
	row, ok := m.selected()
	if !ok || row.Kind != "workspace" || !m.showPreview || m.previewLoading || len(m.preview.Panes) < 2 {
		return
	}
	index := 0
	for i, p := range m.preview.Panes {
		if p.ID == m.preview.PaneID {
			index = i
			break
		}
	}
	panes := m.preview.Panes
	m.selectPreviewPane(panes[(index+direction+len(panes))%len(panes)].ID)
	m.status = ""
}

func (m *model) previewPaneRow(row tuios.Row) tuios.Row {
	row.Label = m.preview.Title
	row.Kind = "pane"
	row.ID = "pane:" + row.SessionID + ":" + m.preview.PaneID
	row.Number = m.preview.Workspace
	return row
}
