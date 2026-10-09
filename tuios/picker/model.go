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
}
type loadedMsg struct {
	snapshot tuios.Snapshot
	err      error
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
	service                                controller
	mode                                   string
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
	status, anchor                         string
}

func newInput() textinput.Model {
	i := textinput.New()
	i.SetVirtualCursor(true)
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
	m := &model{service: service, mode: mode, expanded: map[string]bool{}, search: newInput(), prompt: newInput(), viewport: viewport.New(), showPreview: true, loading: true, width: 80, height: 24}
	if mode == "workspaces" {
		m.search.Placeholder = "이름 / 번호 검색"
	} else {
		m.search.Placeholder = "세션 / workspace 검색"
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
	return tea.Batch(m.search.Focus(), m.reload())
}
func (m *model) reload() tea.Cmd {
	m.loading = true
	return func() tea.Msg { s, err := m.service.Snapshot(m.mode); return loadedMsg{s, err} }
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
	switch kind {
	case "rename":
		m.prompt.Prompt = "새 이름 › "
		m.prompt.SetValue(row.Label)
	case "create-session":
		m.prompt.Prompt = "새 session › "
	case "create-workspace":
		m.prompt.Prompt = "새 workspace › "
	case "close":
		m.prompt.Prompt = ""
	}
	return m.prompt.Focus()
}

func (m *model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	defer func() { m.resize(); m.keepVisible() }()
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.resize()
		m.keepVisible()
		return m, nil
	case loadedMsg:
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
		m.viewport.GotoBottom()
		return m, nil
	case actionMsg:
		m.busy = false
		if msg.err != nil {
			m.status = msg.err.Error()
			return m, nil
		}
		if msg.result.Exit {
			return m, tea.Quit
		}
		if msg.result.Selected != "" {
			m.anchor = msg.result.Selected
			m.search.Reset()
			m.busy = true // Wait for the new row before accepting Enter to navigate.
		}
		m.status = ""
		return m, m.reload()
	case tea.KeyPressMsg:
		key := msg.String()
		if key == "ctrl+c" {
			return m, tea.Quit
		}
		if m.busy {
			return m, nil
		}
		if m.modal != "" {
			if key == "esc" || m.modal == "close" && (key == "n" || key == "enter") {
				m.modal = ""
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
					m.anchor = row.Parent
					return m, m.perform("close", row, "")
				}
				return m, nil
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
		before := m.selectedID()
		switch key {
		case "esc":
			return m, tea.Quit
		case "ctrl+n", "down":
			m.move(1, false)
		case "ctrl+p", "up":
			m.move(-1, false)
		case "ctrl+j":
			m.move(1, true)
		case "ctrl+k":
			m.move(-1, true)
		case "tab", "ctrl+o":
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
		case "ctrl+a":
			if m.mode == "sessions" {
				return m, m.openModal("create-session", tuios.Row{})
			}
			return m, m.openModal("create-workspace", tuios.Row{})
		case "enter":
			if row, ok := m.selected(); ok {
				return m, m.perform("enter", row, "")
			}
		default:
			value := m.search.Value()
			var cmd tea.Cmd
			m.search, cmd = m.search.Update(msg)
			if m.search.Value() != value {
				m.refilter("", true)
				return m, tea.Batch(cmd, m.requestPreview())
			}
			return m, cmd
		}
		if before != m.selectedID() {
			return m, m.requestPreview()
		}
		return m, nil
	}
	value, before := m.search.Value(), m.selectedID()
	var cmd tea.Cmd
	if m.modal != "" {
		m.prompt, cmd = m.prompt.Update(message)
	} else {
		m.search, cmd = m.search.Update(message)
	}
	// Paste is a separate message in Bubble Tea. It must re-filter too.
	if m.search.Value() != value {
		m.refilter("", true)
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
