package main

import (
	"strings"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
)

func (m *model) creating() bool { return strings.HasPrefix(m.modal, "create-") }

// Capture the parent when the form opens. A refresh or newly selected child
// must never redirect the next item in a sequence to another parent.
func (m *model) openCreation() tea.Cmd {
	m.creationChild = tuios.Row{}
	m.status = ""
	m.creationLocation = "현재 session"
	for _, row := range m.rows {
		if row.Session != "" {
			m.creationLocation = row.Session
			break
		}
	}
	if row, ok := m.selected(); ok {
		if row.Parent != "" {
			for _, parent := range m.rows {
				if parent.ID == row.Parent {
					row = parent
					break
				}
			}
		}
		if m.mode == "sessions" && row.Kind == "session" || m.mode == "workspaces" && row.Kind == "workspace" {
			m.creationChild = row
		}
	}
	kind := "create-session"
	if m.mode == "workspaces" {
		kind = "create-workspace"
	}
	cmd := m.openModal(kind, tuios.Row{})
	if row, ok := m.selected(); ok && row.Parent != "" && m.creationChild.ID != "" {
		m.switchCreation()
	}
	return cmd
}

func (m *model) switchCreation() {
	if m.creationChild.ID == "" {
		m.status = "하위 항목을 추가할 " + m.creationParentKind() + "을 먼저 선택하세요"
		return
	}
	m.status = ""
	if m.modalRow.ID == "" {
		m.modalRow = m.creationChild
		m.modal = "create-workspace"
		m.prompt.Prompt = "새 workspace › "
		if m.mode == "workspaces" {
			m.modal = "create-pane"
			m.prompt.Prompt = "새 pane › "
		}
	} else {
		m.modalRow = tuios.Row{}
		m.modal = "create-session"
		m.prompt.Prompt = "새 session › "
		if m.mode == "workspaces" {
			m.modal = "create-workspace"
			m.prompt.Prompt = "새 workspace › "
		}
	}
}

func (m *model) creationParentKind() string {
	if m.mode == "workspaces" {
		return "workspace"
	}
	return "session"
}

func (m *model) creationDestination() string {
	if m.modal == "create-session" {
		return ""
	}
	if m.modalRow.ID == "" {
		return m.creationLocation
	}
	if m.modal == "create-pane" {
		return m.creationLocation + " › " + workspaceLabel(m.modalRow)
	}
	return m.modalRow.Label
}
