package main

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
)

func (m *model) sessionCreation() bool { return m.modal == "create-session" }

// A slash inside a branch name is still a project query. Only an explicit
// path prefix switches to filesystem completion.
func locationPath(value string) bool {
	return value == "~" || value == "." || value == ".." || strings.HasPrefix(value, "/") || strings.HasPrefix(value, "~/") || strings.HasPrefix(value, "./") || strings.HasPrefix(value, "../")
}

func (m *model) openSessionFolder() tea.Cmd {
	m.folderEditing, m.projectOpen = true, false
	m.creationFocus = 1
	m.prompt.Blur()
	m.folderInput.Prompt = "시작 폴더 › "
	m.folderInput.Placeholder = "프로젝트 / worktree 검색 또는 ~/경로"
	m.status = ""
	m.resize()
	m.refreshSessionFolders()
	if m.folderInput.Value() == m.creationAcceptedQuery {
		for i, choice := range m.folderChoices {
			if choice.path == m.creationFolder.Path {
				m.folderChoiceIndex = i
				break
			}
		}
	}
	focus := m.folderInput.Focus()
	if m.projects == nil {
		return tea.Batch(focus, m.loadProjects())
	}
	return focus
}

func (m *model) refreshSessionFolders() {
	query := m.folderInput.Value()
	m.folderChoices = nil
	m.folderChoiceIndex = -1
	m.status = ""
	if locationPath(query) {
		choices, err := completeFolders(query, m.creationBase)
		if err != nil {
			m.status = err.Error()
		} else {
			m.folderChoices = choices
		}
		return
	}
	type match struct {
		choice folderChoice
		score  int
	}
	var matches []match
	for _, choice := range m.projects {
		if score, ok := matchQuery(choice.label, query); ok {
			matches = append(matches, match{choice, score})
		}
	}
	sort.SliceStable(matches, func(i, j int) bool { return matches[i].score > matches[j].score })
	if query == "" && m.creationBase != "" {
		m.folderChoices = append(m.folderChoices, folderChoice{path: m.creationBase, label: "현재 작업 폴더"})
	}
	for _, hit := range matches {
		// Keep the current folder once, under its explicit context label.
		if query == "" && hit.choice.path == m.creationBase {
			continue
		}
		m.folderChoices = append(m.folderChoices, hit.choice)
	}
	if len(m.folderChoices) > 0 {
		m.folderChoiceIndex = 0
	}
}

func (m *model) acceptSessionFolder(value string) tea.Cmd {
	if m.folderLoading {
		m.status = "시작 폴더를 확인하는 중입니다"
		return nil
	}
	path, err := tuios.ResolveCreationFolder(value, m.creationBase)
	if err != nil {
		m.status = err.Error()
		return nil
	}
	m.creationFolder = tuios.CreationFolder{Path: path, Source: "이번 생성에 지정한 폴더"}
	m.creationAcceptedQuery = m.folderInput.Value()
	// A chosen project never overwrites a name the user has edited.
	if m.prompt.Value() == "" || m.prompt.Value() == m.creationSuggestedName {
		m.creationSuggestedName = filepath.Base(path)
		m.prompt.SetValue(m.creationSuggestedName)
		m.prompt.CursorEnd()
	}
	m.folderInput.CursorEnd()
	m.folderEditing = false
	m.folderInput.Blur()
	m.creationFocus = 0
	m.status = ""
	return m.prompt.Focus()
}

func (m *model) updateSessionFolder(msg tea.KeyPressMsg) tea.Cmd {
	key := msg.String()
	switch key {
	case "ctrl+n", "ctrl+j", "down", "ctrl+p", "ctrl+k", "up":
		if len(m.folderChoices) > 0 {
			step := 1
			if key == "ctrl+p" || key == "ctrl+k" || key == "up" {
				step = -1
			}
			if m.folderChoiceIndex < 0 {
				if step > 0 {
					m.folderChoiceIndex = 0
				} else {
					m.folderChoiceIndex = len(m.folderChoices) - 1
				}
			} else {
				m.folderChoiceIndex = max(0, min(len(m.folderChoices)-1, m.folderChoiceIndex+step))
			}
		}
		return nil
	case "pgdown", "pgup":
		step := max(1, m.dimensions().leftH-15)
		if key == "pgup" {
			step = -step
		}
		m.folderChoiceIndex = max(0, min(len(m.folderChoices)-1, m.folderChoiceIndex+step))
		return nil
	case "ctrl+l":
		if locationPath(m.folderInput.Value()) && len(m.folderChoices) > 0 {
			choice := m.folderChoices[max(0, m.folderChoiceIndex)]
			m.folderInput.SetValue(choice.path)
			m.folderInput.CursorEnd()
			m.refreshSessionFolders()
		}
		return nil
	case "enter", "ctrl+enter":
		accept := func(path string) tea.Cmd {
			cmd := m.acceptSessionFolder(path)
			if key == "ctrl+enter" && !m.folderEditing {
				return m.create()
			}
			return cmd
		}
		value := m.folderInput.Value()
		if m.folderChoiceIndex >= 0 && m.folderChoiceIndex < len(m.folderChoices) {
			return accept(m.folderChoices[m.folderChoiceIndex].path)
		}
		if value == "" {
			return accept(m.creationFolder.Path)
		}
		if locationPath(value) {
			return accept(value)
		}
		if m.projectLoading {
			m.status = "프로젝트 목록을 불러오는 중입니다"
		} else {
			m.status = "일치하는 프로젝트가 없습니다 · 경로는 /, ~/ 또는 ./로 시작하세요"
		}
		return nil
	case "f5":
		return m.loadProjects() // Retry a failed project lookup without another screen.
	case "esc":
		m.folderEditing = false
		m.folderInput.Blur()
		m.modal = ""
		m.status = ""
		return m.search.Focus()
	}
	before := m.folderInput.Value()
	var cmd tea.Cmd
	m.folderInput, cmd = m.folderInput.Update(msg)
	if before != m.folderInput.Value() {
		m.refreshSessionFolders()
	}
	return cmd
}

// Name and folder fields have stable positions. A bounded list makes the
// selected candidate, scroll range and committed directory unambiguous.
func (m *model) sessionCreationLines(width, height int) (lines []string, folderLine, nameLine int) {
	inner := max(1, width-4)
	lines = []string{m.styles.bright.Render("종류  [ Session ]   Workspace"), ""}
	nameLine = len(lines)
	lines = append(lines, m.prompt.View(), "")
	folderLine = len(lines)
	path := m.creationFolder.Path
	if m.folderLoading {
		path = "확인 중…"
	}
	if !m.folderEditing {
		lines = append(lines, m.styles.bright.Render(fit("시작 폴더  "+path, inner)))
		if m.folderInput.Value() != m.creationAcceptedQuery {
			lines = append(lines, m.styles.muted.Render("검색 미확정 · Tab으로 돌아가 폴더를 선택하세요"))
		} else {
			lines = append(lines, m.styles.muted.Render("Tab / Ctrl-o로 폴더 변경"))
		}
		lines = append(lines, "", m.styles.pointer.Render("[ 세션 만들기 · Enter ]"), m.styles.muted.Render("이름과 시작 폴더로 새 세션을 만듭니다"))
		return lines, folderLine, nameLine
	}
	lines = append(lines, m.folderInput.View(), m.styles.muted.Render("Enter 선택 후 이름 확인 · Ctrl-Enter 선택하고 바로 생성"), "")
	capacity := max(1, height-len(lines)-5)
	count := len(m.folderChoices)
	index := m.folderChoiceIndex
	start := max(0, index-capacity+1)
	end := min(count, start+capacity)
	mode := "프로젝트 · worktree"
	if locationPath(m.folderInput.Value()) {
		mode = "폴더"
	}
	position := fmt.Sprintf("총 %d개", count)
	if m.folderEditing {
		position = fmt.Sprintf("%d / %d", max(0, index+1), count)
	}
	boxWidth := max(1, inner-2)
	border := func(left, label, right string) string {
		label = fit(" "+label+" ", boxWidth)
		return m.styles.border.Render(left + label + strings.Repeat("─", max(0, boxWidth-ansi.StringWidth(label))) + right)
	}
	row := func(text string) string { return "│" + pad(text, boxWidth) + "│" }
	lines = append(lines, border("┌", mode+" 후보  "+position, "┐"))
	if count == 0 {
		label := "일치하는 후보 없음"
		if m.projectLoading && !locationPath(m.folderInput.Value()) {
			label = "프로젝트 불러오는 중…"
		}
		lines = append(lines, m.styles.muted.Render(row(" "+label)))
	} else {
		for i := start; i < end; i++ {
			prefix, style := "   ", m.styles.normal
			if i == index && m.folderEditing {
				prefix, style = " › ", m.styles.pointer.Background(m.styles.selection).Bold(true)
			}
			lines = append(lines, style.Render(row(prefix+tuios.Clean(m.folderChoices[i].label))))
		}
	}
	scroll := fmt.Sprintf("표시 %d–%d / %d", min(count, start+1), end, count)
	if start > 0 {
		scroll += "  ↑ 더 있음"
	}
	if end < count {
		scroll += "  ↓ 더 있음"
	}
	lines = append(lines, border("└", scroll, "┘"))
	if index >= 0 && index < count && m.folderEditing {
		lines = append(lines, m.styles.muted.Render(fit("후보 경로  "+m.folderChoices[index].path, inner)))
	}
	return lines, folderLine, nameLine
}
