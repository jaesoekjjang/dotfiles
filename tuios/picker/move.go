package main

import tea "charm.land/bubbletea/v2"

func (m *model) updateMove(msg tea.KeyPressMsg) tea.Cmd {
	switch msg.String() {
	case "esc":
		return tea.Quit
	case "ctrl+n", "ctrl+j", "down":
		m.move(1, false)
	case "ctrl+p", "ctrl+k", "up":
		m.move(-1, false)
	case "enter":
		if row, ok := m.selected(); ok {
			return m.perform("move", row, "")
		}
	default:
		before := m.search.Value()
		var cmd tea.Cmd
		m.search, cmd = m.search.Update(msg)
		if before != m.search.Value() {
			m.refilter("", true)
		}
		return cmd
	}
	return nil
}
