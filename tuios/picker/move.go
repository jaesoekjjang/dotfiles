package main

import tea "charm.land/bubbletea/v2"

func (m *model) updateMove(msg tea.KeyPressMsg) tea.Cmd {
	switch msg.String() {
	case "esc":
		return m.escapeSearch()
	case "ctrl+n", "ctrl+l", "ctrl+j", "down":
		m.move(1, false)
	case "ctrl+p", "ctrl+h", "ctrl+k", "up":
		m.move(-1, false)
	case "enter", "ctrl+enter":
		if row, ok := m.selected(); ok {
			action := "move"
			if msg.String() == "ctrl+enter" {
				action = "move-stay"
			}
			return m.perform(action, row, "")
		}
	default:
		before, anchor := m.search.Value(), m.selectedID()
		var cmd tea.Cmd
		m.search, cmd = m.search.Update(msg)
		if before != m.search.Value() {
			m.searchChanged(before, anchor)
		}
		return cmd
	}
	return nil
}
