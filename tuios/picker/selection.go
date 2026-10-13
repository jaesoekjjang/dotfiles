package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
)

// Pick from the visible results before deleting, excluding the removed subtree.
// A stable ID survives list compaction, search filtering and MRU ordering.
func (m *model) afterClose(row tuios.Row) string {
	index := -1
	for i, r := range m.visible {
		if r.ID == row.ID {
			index = i
			break
		}
	}
	if index < 0 {
		return ""
	}
	for i := index + 1; i < len(m.visible); i++ {
		r := m.visible[i]
		if r.Parent == row.Parent {
			return r.ID
		}
	}
	for i := index - 1; i >= 0; i-- {
		r := m.visible[i]
		if r.Parent == row.Parent {
			return r.ID
		}
	}
	for _, r := range m.visible {
		if r.ID == row.Parent {
			return r.ID
		}
	}
	for i := index + 1; i < len(m.visible); i++ {
		if m.visible[i].Parent != row.ID {
			return m.visible[i].ID
		}
	}
	if index > 0 {
		return m.visible[index-1].ID
	}
	return ""
}

func (m *model) searchChanged(previous, selected string) {
	if previous == "" && m.search.Value() != "" {
		m.searchAnchor = selected
	}
	if m.search.Value() == "" {
		m.refilter(m.searchAnchor, false)
		m.searchAnchor = ""
	} else {
		m.refilter("", true)
	}
}
func (m *model) escapeSearch() tea.Cmd {
	if m.search.Value() == "" {
		return tea.Quit
	}
	m.search.Reset()
	m.refilter(m.searchAnchor, false)
	m.searchAnchor = ""
	return m.requestPreview()
}
