package main

import (
	"fmt"
	"slices"
	"strings"
	"time"

	"charm.land/bubbles/v2/textinput"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
)

type controller interface {
	Snapshot(string) (tuios.Snapshot, error)
	Preview(tuios.Row) (tuios.Preview, error)
	Act(string, tuios.Row, string) (tuios.ActionResult, error)
	CreationFolder(tuios.Row) (tuios.CreationFolder, error)
	Create(string, tuios.Row, string, string) (tuios.ActionResult, error)
}
type loadedMsg struct {
	snapshot   tuios.Snapshot
	err        error
	generation int
}
type previewRequest struct {
	generation int
	row        tuios.Row
}
type previewMsg struct {
	generation int
	preview    tuios.Preview
	err        error
}
type actionMsg struct {
	result tuios.ActionResult
	err    error
}

type model struct {
	layoutRefreshing                       bool
	searchAnchor                           string
	agentRefreshing                        bool
	service                                controller
	mode                                   string
	loadGeneration                         int
	rows, visible                          []tuios.Row
	expanded                               map[string]bool
	index, offset                          int
	search, prompt                         textinput.Model
	viewport                               viewport.Model
	preview                                tuios.Preview
	showPreview, loading, busy, standalone bool
	width, height, generation              int
	previewLoading                         bool
	modal                                  string
	modalRow                               tuios.Row
	inputTarget                            string
	creationChild                          tuios.Row
	creationLocation                       string
	creationFolder                         tuios.CreationFolder
	creationBase                           string
	folderInput                            textinput.Model
	folderEditing, folderLoading           bool
	folderGeneration                       int
	creationFocus                          int // 0 name, 1 folder, 2 kind
	folderChoices, projects                []folderChoice
	folderChoiceIndex                      int
	projectInput                           textinput.Model
	projectOpen, projectLoading            bool
	projectGeneration                      int
	status, anchor                         string
}

func newInput() textinput.Model {
	i := textinput.New()
	i.SetVirtualCursor(false)
	i.Prompt = "찾기 › "
	i.Placeholder = "이름 검색"
	styles := textinput.DefaultDarkStyles()
	styles.Focused.Text = normal
	styles.Focused.Prompt = bright
	styles.Focused.Placeholder = muted
	styles.Blurred = styles.Focused
	styles.Cursor.Color = cyan
	i.SetStyles(styles)
	return i
}

func newModel(service controller, mode string) *model {
	m := &model{service: service, mode: mode, expanded: map[string]bool{}, search: newInput(), prompt: newInput(), folderInput: newInput(), projectInput: newInput(), viewport: viewport.New(), showPreview: true, loading: true, width: 80, height: 24}
	if mode == "workspaces" {
		m.search.Placeholder = "이름 / 번호 검색"
	} else {
		m.search.Placeholder = "세션 / workspace 검색"
	}
	if mode == "move-pane" {
		m.showPreview = false
		m.search.Placeholder = "보낼 workspace 검색"
	}
	m.viewport.SoftWrap = false
	m.viewport.FillHeight = true
	m.search.Focus()
	m.resize()
	return m
}
func (m *model) Init() tea.Cmd {
	if m.standalone {
		return nil
	}
	return tea.Batch(m.search.Focus(), m.reload(), nextAgentTick())
}
func (m *model) reload() tea.Cmd {
	m.loading = true
	m.loadGeneration++
	generation, mode := m.loadGeneration, m.mode
	return func() tea.Msg {
		snapshot, err := m.service.Snapshot(mode)
		return loadedMsg{snapshot: snapshot, err: err, generation: generation}
	}
}

func (m *model) selected() (tuios.Row, bool) {
	if m.index < 0 || m.index >= len(m.visible) {
		return tuios.Row{}, false
	}
	return m.visible[m.index], true
}
func (m *model) selectedID() string { r, _ := m.selected(); return r.ID }
func (m *model) refilter(anchor string, first bool) {
	m.visible = filterRows(m.rows, m.expanded, m.search.Value())
	index := slices.IndexFunc(m.visible, func(r tuios.Row) bool { return r.ID == anchor })
	if first {
		m.index = 0
	} else if index >= 0 {
		m.index = index
	} else {
		m.index = min(m.index, max(0, len(m.visible)-1))
	}
	m.keepVisible()
}
func (m *model) keepVisible() {
	h := m.listHeight()
	if m.index < m.offset {
		m.offset = m.index
	}
	if m.index >= m.offset+h {
		m.offset = m.index - h + 1
	}
	m.offset = max(0, min(m.offset, max(0, len(m.visible)-h)))
}
func (m *model) move(step int, group bool) {
	if len(m.visible) == 0 {
		return
	}
	parent := m.visible[m.index].ID
	if m.visible[m.index].Parent != "" {
		parent = m.visible[m.index].Parent
		// Moving backward from a child first reaches its own visible parent.
		// If search hides it, keep traversing the groups in the result list.
		if group && step < 0 {
			if i := slices.IndexFunc(m.visible, func(r tuios.Row) bool { return r.ID == parent }); i >= 0 {
				m.index = i
				m.keepVisible()
				return
			}
		}
	}
	for n := 1; n <= len(m.visible); n++ {
		i := (m.index + step*n + len(m.visible)*n) % len(m.visible)
		candidate := m.visible[i]
		candidateGroup := candidate.ID
		landing := candidate.Parent == ""
		if candidate.Parent != "" {
			candidateGroup = candidate.Parent
			// Filtered workspace results still allow jumping between sessions
			// when their parent session rows did not match the query.
			landing = m.mode == "sessions" && !slices.ContainsFunc(m.visible, func(r tuios.Row) bool { return r.ID == candidate.Parent })
		}
		if !group || landing && candidateGroup != parent {
			m.index = i
			m.keepVisible()
			return
		}
	}
	if group {
		if i := slices.IndexFunc(m.visible, func(r tuios.Row) bool { return r.ID == parent }); i >= 0 {
			m.index = i
		}
	}
	m.keepVisible()
}
func (m *model) toggle(all bool) {
	anchor := m.selectedID()
	if all {
		open := false
		for _, r := range m.rows {
			if r.Parent == "" && !m.expanded[r.ID] {
				open = true
				break
			}
		}
		if !open {
			if r, ok := m.selected(); ok && r.Parent != "" {
				anchor = r.Parent
			}
		}
		for _, r := range m.rows {
			if r.Parent == "" {
				m.expanded[r.ID] = open
			}
		}
	} else {
		r, ok := m.selected()
		if !ok {
			return
		}
		if r.Parent != "" {
			anchor = r.Parent
			m.expanded[r.Parent] = false
		} else {
			m.expanded[r.ID] = !m.expanded[r.ID]
		}
	}
	m.refilter(anchor, false)
}
func (m *model) requestPreview() tea.Cmd {
	m.generation++
	if !m.showPreview {
		return nil
	}
	r, ok := m.selected()
	m.preview = tuios.Preview{}
	m.viewport.SetContent("")
	m.previewLoading = ok
	if !ok {
		return nil
	}
	request := previewRequest{m.generation, r}
	return tea.Tick(35*time.Millisecond, func(time.Time) tea.Msg { return request })
}
func (m *model) perform(action string, row tuios.Row, name string) tea.Cmd {
	m.busy = true
	m.status = "처리 중…"
	return func() tea.Msg { result, err := m.service.Act(action, row, name); return actionMsg{result, err} }
}
func (m *model) openModal(kind string, row tuios.Row) tea.Cmd {
	m.modal = kind
	m.modalRow = row
	m.search.Blur()
	m.prompt.Reset()
	if strings.HasPrefix(kind, "create-") {
		m.prompt.Placeholder = "이름"
	}
	switch kind {
	case "rename":
		m.prompt.Prompt = "새 이름 › "
		m.prompt.SetValue(row.Label)
	case "create-session":
		m.prompt.Prompt = "새 session › "
	case "create-workspace":
		m.prompt.Prompt = "새 workspace › "
	case "create-pane":
		m.prompt.Prompt = "새 pane › "
	case "close":
		m.prompt.Prompt = ""
	case "send":
		m.prompt.Prompt = "보낼 내용 › "
		m.prompt.Placeholder = "한 줄 입력 후 Enter로 전송"
	}
	return m.prompt.Focus()
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	defer func() { m.resize(); m.keepVisible() }()
	switch msg := message.(type) {
	case agentTick:
		if m.loading || m.busy || m.modal != "" || m.agentRefreshing {
			return m, nextAgentTick()
		}
		m.agentRefreshing = true
		mode := m.mode
		return m, tea.Batch(nextAgentTick(), func() tea.Msg {
			snapshot, err := m.service.Snapshot(mode)
			return agentRefresh{snapshot, err}
		})
	case agentRefresh:
		m.agentRefreshing = false
		if msg.err != nil || m.loading || m.busy || m.modal != "" {
			return m, nil
		}
		counts := map[string]tuios.AgentCounts{}
		for _, row := range msg.snapshot.Rows {
			counts[row.ID] = row.Agents
		}
		for i := range m.rows {
			if a, ok := counts[m.rows[i].ID]; ok {
				m.rows[i].Agents = a
			}
		}
		m.refilter(m.selectedID(), false)
		if (len(m.preview.Panes) > 1 || m.preview.Overview) && m.showPreview && !m.previewLoading && !m.layoutRefreshing {
			if row, ok := m.selected(); ok {
				m.layoutRefreshing = true
				generation := m.generation
				return m, func() tea.Msg { p, err := m.service.Preview(row); return layoutRefresh{generation, p, err} }
			}
		}
		return m, nil
	case layoutRefresh:
		m.layoutRefreshing = false
		if msg.generation == m.generation && m.showPreview && m.modal == "" && !m.busy && msg.err == nil {
			selectedPane := m.preview.PaneID
			m.preview = msg.preview
			m.selectPreviewPane(selectedPane)
			if len(msg.preview.Panes) < 2 {
				m.viewport.SetContent(screenText(msg.preview.Screen))
				if !msg.preview.Overview {
					m.viewport.GotoBottom()
				}
			}
		}
		return m, nil
	case projectsMsg:
		if !m.projectOpen || msg.generation != m.projectGeneration {
			return m, nil
		}
		m.projectLoading = false
		if msg.err != nil {
			m.status = "프로젝트 목록: " + msg.err.Error()
			return m, nil
		}
		m.projects = msg.choices
		m.filterProjects()
		return m, nil
	case creationFolderMsg:
		if !m.creating() || msg.generation != m.folderGeneration {
			return m, nil
		}
		m.folderLoading = false
		if msg.err != nil {
			m.status = msg.err.Error() + " · Ctrl+O로 시작 폴더를 지정하세요"
			return m, nil
		}
		m.creationFolder = msg.folder
		m.creationBase = msg.folder.Path
		return m, nil
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.resize()
		m.keepVisible()
		return m, nil
	case loadedMsg:
		if msg.generation != 0 && msg.generation != m.loadGeneration {
			return m, nil
		}
		m.loading = false
		m.busy = false
		if msg.err != nil {
			m.status = msg.err.Error()
			return m, nil
		}
		old := m.selectedID()
		if m.anchor != "" {
			old = m.anchor
			m.anchor = ""
		}
		if len(m.rows) == 0 && old == "" {
			old = msg.snapshot.Current
		}
		known := map[string]bool{}
		for _, r := range m.rows {
			if r.Parent == "" {
				known[r.ID] = true
			}
		}
		for _, r := range msg.snapshot.Rows {
			if r.Parent == "" && !known[r.ID] {
				m.expanded[r.ID] = true
			}
		}
		m.rows = msg.snapshot.Rows
		m.refilter(old, false)
		return m, m.requestPreview()
	case previewRequest:
		if msg.generation != m.generation || !m.showPreview {
			return m, nil
		}
		return m, func() tea.Msg { p, err := m.service.Preview(msg.row); return previewMsg{msg.generation, p, err} }
	case previewMsg:
		if msg.generation != m.generation || !m.showPreview {
			return m, nil
		}
		m.previewLoading = false
		m.preview = msg.preview
		if msg.err != nil {
			m.preview.Screen = "미리보기를 불러오지 못했습니다.\n" + tuios.Clean(msg.err.Error())
		}
		m.viewport.SetContent(screenText(m.preview.Screen))
		if m.preview.Overview {
			m.viewport.GotoTop()
		} else {
			m.viewport.GotoBottom()
		}
		return m, nil
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.anchor = ""
			m.status = msg.err.Error()
			return m, nil
		}
		if m.modal == "send" {
			m.modal = ""
			m.prompt.Reset()
			m.prompt.Blur()
			m.search.Focus()
			m.status = "입력 전송됨 · " + m.inputTarget + " › " + m.modalRow.Label
			return m, m.requestPreview()
		}
		if msg.result.Exit {
			return m, tea.Quit
		}
		m.status = ""
		if m.creating() {
			m.status = strings.TrimSpace(m.prompt.Value()) + " 생성됨"
			if m.modalRow.ID != "" {
				m.expanded[m.modalRow.ID] = true
			}
			m.modal = ""
			m.prompt.Blur()
			m.search.Focus()
		}
		if msg.result.Warning != "" {
			m.status = msg.result.Warning
		}
		if msg.result.Selected != "" {
			m.anchor = msg.result.Selected
			m.search.Reset()
			m.busy = true // Wait for the new row before accepting Enter to navigate.
		}
		return m, m.reload()
	case tea.KeyPressMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return m, tea.Quit
		}
		if m.busy {
			return m, nil
		}
		if m.folderEditing {
			return m, m.updateFolder(msg)
		}
		if m.modal != "" {
			if key == "esc" || m.modal == "close" && (key == "n" || key == "enter") {
				m.modal = ""
				m.status = ""
				m.prompt.Blur()
				if m.standalone {
					return m, tea.Quit
				}
				return m, m.search.Focus()
			}
			if m.modal == "close" {
				if key == "y" {
					row := m.modalRow
					m.modal = ""
					m.prompt.Blur()
					m.search.Focus()
					m.anchor = m.afterClose(row)
					return m, m.perform("close", row, "")
				}
				return m, nil
			}
			if m.creating() {
				if key == "ctrl+o" {
					return m, m.openFolder()
				}
				if key == "tab" || key == "shift+tab" {
					m.switchCreation()
					return m, nil
				}
				if key == "ctrl+n" || key == "ctrl+p" || key == "ctrl+h" || key == "ctrl+l" || key == "ctrl+j" || key == "ctrl+k" {
					step := 1
					if key == "ctrl+p" || key == "ctrl+h" || key == "ctrl+k" {
						step = -1
					}
					m.creationFocus = (m.creationFocus + step + 3) % 3
					m.prompt.Blur()
					if m.creationFocus == 0 {
						return m, m.prompt.Focus()
					}
					return m, nil
				}
				if m.creationFocus == 2 {
					if key == "space" || key == " " || key == "enter" {
						m.switchCreation()
					}
					return m, nil
				}
				if m.creationFocus == 1 {
					if key == "enter" {
						return m, m.openFolder()
					}
					return m, nil
				}
				if key == "enter" {
					if strings.TrimSpace(m.prompt.Value()) == "" {
						m.status = "이름을 입력하세요"
						return m, nil
					}
					return m, m.create()
				}
			}
			if m.modal == "send" && key == "enter" {
				if strings.TrimSpace(m.prompt.Value()) == "" {
					m.status = "보낼 내용을 입력하세요"
					return m, nil
				}
				return m, m.perform("send", m.modalRow, m.prompt.Value())
			}
			if key == "enter" {
				action, row, name := m.modal, m.modalRow, strings.TrimSpace(m.prompt.Value())
				m.modal = ""
				m.prompt.Blur()
				m.search.Focus()
				if name == "" {
					return m, nil
				}
				m.anchor = row.ID
				return m, m.perform(action, row, name)
			}
			var cmd tea.Cmd
			m.prompt, cmd = m.prompt.Update(msg)
			return m, cmd
		}
		if m.mode == "move-pane" {
			return m, m.updateMove(msg)
		}
		before := m.selectedID()
		switch key {
		case "esc":
			return m, m.escapeSearch()
		case "ctrl+n", "ctrl+l":
			m.move(1, true)
		case "ctrl+p", "ctrl+h":
			m.move(-1, true)
		case "ctrl+j", "down":
			m.move(1, false)
		case "ctrl+k", "up":
			m.move(-1, false)
		case "tab", "shift+tab":
			direction := 1
			if key == "shift+tab" {
				direction = -1
			}
			m.cyclePreviewPane(direction)
			return m, nil
		case "ctrl+o":
			m.toggle(false)
		case "ctrl+g":
			m.toggle(true)
		case "shift+up":
			m.viewport.ScrollUp(1)
			return m, nil
		case "shift+down":
			m.viewport.ScrollDown(1)
			return m, nil
		case "ctrl+u":
			m.viewport.HalfPageUp()
			return m, nil
		case "ctrl+d":
			m.viewport.HalfPageDown()
			return m, nil
		case "ctrl+/", "ctrl+_":
			m.showPreview = !m.showPreview
			m.resize()
			return m, m.requestPreview()
		case "ctrl+x":
			if row, ok := m.selected(); ok {
				return m, m.openModal("close", row)
			}
		case "ctrl+r":
			if row, ok := m.selected(); ok {
				return m, m.openModal("rename", row)
			}
		case "ctrl+s":
			if row, ok := m.selected(); ok {
				if !m.showPreview || m.previewLoading || m.preview.PaneID == "" {
					m.status = "입력할 workspace 또는 pane을 선택하세요"
					return m, nil
				}
				m.inputTarget = m.preview.Location
				row = m.previewPaneRow(row)
				m.status = ""
				return m, m.openModal("send", row)
			}
		case "ctrl+a":
			if m.loading && len(m.rows) == 0 {
				m.status = "목록을 불러오는 중입니다"
				return m, nil
			}
			return m, m.openCreation()
		case "enter":
			if row, ok := m.selected(); ok {
				if row.Kind == "workspace" && m.showPreview && !m.previewLoading && m.preview.PaneID != "" {
					row = m.previewPaneRow(row)
				}
				return m, m.perform("enter", row, "")
			}
		default:
			value := m.search.Value()
			var cmd tea.Cmd
			m.search, cmd = m.search.Update(msg)
			if m.search.Value() != value {
				m.searchChanged(value, before)
				return m, tea.Batch(cmd, m.requestPreview())
			}
			return m, cmd
		}
		if before != m.selectedID() {
			return m, m.requestPreview()
		}
		return m, nil
	}
	if m.busy {
		return m, nil
	}
	value, before := m.search.Value(), m.selectedID()
	var cmd tea.Cmd
	if m.folderEditing {
		if m.projectOpen {
			before := m.projectInput.Value()
			m.projectInput, cmd = m.projectInput.Update(message)
			if before != m.projectInput.Value() {
				m.filterProjects()
			}
		} else {
			before := m.folderInput.Value()
			m.folderInput, cmd = m.folderInput.Update(message)
			if before != m.folderInput.Value() {
				m.refreshFolderChoices()
			}
		}
	} else if m.modal != "" {
		m.prompt, cmd = m.prompt.Update(message)
	} else {
		m.search, cmd = m.search.Update(message)
	}
	// Paste is a separate message in Bubble Tea. It must re-filter too.
	if m.search.Value() != value {
		m.searchChanged(value, before)
		return m, tea.Batch(cmd, m.requestPreview())
	}
	m.refilter(before, false)
	return m, cmd
}

func workspaceLabel(r tuios.Row) string {
	if r.Parent != "" {
		return fmt.Sprintf("workspace %d · %s", r.Number, r.Label)
	}
	return fmt.Sprintf("%d  %s", r.Number, r.Label)
}

func (m *model) sessionLabel(row tuios.Row) string {
	for _, parent := range m.rows {
		if parent.ID == row.Parent {
			return parent.Label
		}
	}
	return row.Session
}
