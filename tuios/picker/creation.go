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
	selected, _ := m.selected()
	m.folderEditing = false
	m.creationFocus = 0
	m.projectOpen = false
	m.folderChoices = nil
	m.folderLoading = true
	m.folderGeneration++
	m.creationFolder = tuios.CreationFolder{}
	m.creationBase = ""
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
	m.openModal(kind, tuios.Row{})
	if row, ok := m.selected(); ok && row.Parent != "" && m.creationChild.ID != "" {
		m.switchCreation()
	}
	generation := m.folderGeneration
	return func() tea.Msg {
		folder, err := m.service.CreationFolder(selected)
		return creationFolderMsg{generation: generation, folder: folder, err: err}
	}
}

type creationFolderMsg struct {
	generation int
	folder     tuios.CreationFolder
	err        error
}

func (m *model) openFolder() tea.Cmd {
	if m.folderLoading {
		m.status = "시작 폴더를 확인하는 중입니다"
		return nil
	}
	m.folderEditing = true
	m.folderChoices = nil
	m.projectOpen = false
	m.status = ""
	m.prompt.Blur()
	m.folderInput.Prompt = "경로 › "
	m.folderInput.Placeholder = "절대 경로 또는 ~/..."
	m.folderInput.SetValue(m.creationFolder.Path)
	m.folderInput.CursorEnd()
	return m.folderInput.Focus()
}

func (m *model) updateFolder(msg tea.KeyPressMsg) tea.Cmd {
	if m.projectOpen {
		return m.updateProjects(msg)
	}
	key := msg.String()
	if len(m.folderChoices) > 0 {
		switch key {
		case "ctrl+n":
			m.folderChoiceIndex = (m.folderChoiceIndex + 1) % len(m.folderChoices)
			return nil
		case "ctrl+p", "shift+tab":
			if m.folderChoiceIndex < 0 {
				m.folderChoiceIndex = 0
			}
			m.folderChoiceIndex = (m.folderChoiceIndex + len(m.folderChoices) - 1) % len(m.folderChoices)
			return nil
		case "tab", "enter":
			if key == "tab" || m.folderChoiceIndex >= 0 {
				index := max(0, m.folderChoiceIndex)
				m.folderInput.SetValue(m.folderChoices[index].path)
				m.folderInput.CursorEnd()
				m.folderChoices = nil
				return nil
			}
		case "esc":
			m.folderChoices = nil
			return nil
		}
	}
	switch key {
	case "ctrl+o":
		return m.openProjects()
	case "tab":
		m.refreshFolderChoices()
		if len(m.folderChoices) == 1 {
			m.folderInput.SetValue(m.folderChoices[0].path)
			m.folderInput.CursorEnd()
			m.folderChoices = nil
		}
		return nil
	case "esc":
		m.folderEditing = false
		m.folderInput.Blur()
		m.status = ""
		m.creationFocus = 0
		return m.prompt.Focus()
	case "enter":
		path, err := tuios.ResolveCreationFolder(m.folderInput.Value(), m.creationBase)
		if err != nil {
			m.status = err.Error()
			return nil
		}
		m.creationFolder = tuios.CreationFolder{Path: path, Source: "이번 생성에 지정한 폴더"}
		m.folderEditing = false
		m.folderInput.Blur()
		m.status = ""
		m.creationFocus = 0
		return m.prompt.Focus()
	}
	before := m.folderInput.Value()
	var cmd tea.Cmd
	m.folderInput, cmd = m.folderInput.Update(msg)
	if before != m.folderInput.Value() {
		m.refreshFolderChoices()
	}
	return cmd
}

func (m *model) create() tea.Cmd {
	if m.folderLoading {
		m.status = "시작 폴더를 확인하는 중입니다"
		return nil
	}
	if m.creationFolder.Path == "" {
		m.status = "Ctrl+L로 시작 폴더를 지정하세요"
		return nil
	}
	action, row, name, folder := m.modal, m.modalRow, strings.TrimSpace(m.prompt.Value()), m.creationFolder.Path
	m.busy = true
	m.status = "생성 중…"
	return func() tea.Msg {
		result, err := m.service.Create(action, row, name, folder)
		return actionMsg{result: result, err: err}
	}
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
