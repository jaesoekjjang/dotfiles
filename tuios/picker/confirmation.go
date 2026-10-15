package main

import (
	"fmt"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
)

func closeTarget(row tuios.Row) string {
	label := tuios.Clean(row.Label)
	if row.Kind == "workspace" {
		if label == "" || label == "이름 없음" || label == fmt.Sprint(row.Number) {
			return fmt.Sprintf("Workspace %d", row.Number)
		}
		return fmt.Sprintf("Workspace %d · %s", row.Number, label)
	}
	return label
}

func (m *model) closeView() tea.View {
	row := m.modalRow
	kind := "Pane"
	if row.Kind == "workspace" {
		kind = "Workspace"
	} else if row.Kind == "session" {
		kind = "Session"
	}
	width := max(12, min(76, m.width-4))
	inner := max(1, width-4)
	lines := []string{"", m.styles.bright.Bold(true).Render(fit(closeTarget(row), inner))}
	if row.Kind != "session" && row.Parent != "" && !m.standalone {
		context := m.sessionLabel(row)
		if context == "" {
			context = row.Session
		}
		lines = append(lines, m.styles.muted.Render(fit(context, inner)))
	}
	if row.Kind != "pane" {
		lines = append(lines, "", m.styles.normal.Render(fmt.Sprintf("포함된 pane %d개를 모두 종료합니다.", row.Panes)))
	}
	lines = append(lines, "")
	if m.status != "" {
		lines = append(lines, strings.Split(ansi.Hardwrap(m.styles.amber.Render(tuios.Clean(m.status)), inner, true), "\n")...)
	}
	if !m.busy {
		lines = append(lines, strings.Split(ansi.Hardwrap("y 종료 · Enter / n / Esc 취소", inner, true), "\n")...)
	}
	lines = append(lines, "")
	card := m.panel(kind+" 종료", strings.Join(lines, "\n"), width, len(lines)+2)
	if m.standalone {
		// TUIOS already frames the popup; a second border wastes space.
		content := m.styles.bright.Render(kind+" 종료") + "\n\n" + strings.Trim(strings.Join(lines, "\n"), "\n")
		card = lipgloss.NewStyle().Width(inner).Render(content)
	}
	v := tea.NewView(lipgloss.Place(max(width, m.width), max(lipgloss.Height(card), m.height), lipgloss.Center, lipgloss.Center, card))
	v.AltScreen = true
	return v
}
