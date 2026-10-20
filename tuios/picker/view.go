package main

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
	"github.com/junegunn/fzf/src/algo"
	"github.com/junegunn/fzf/src/util"
)

var sgr = regexp.MustCompile("\x1b\\[[0-9;:]*m")

// A captured terminal is data, not instructions to our terminal. Preserve SGR
// styling only; notably OSC titles/links and cursor movement cannot escape the
// preview viewport.
func screenText(raw string) string {
	clean := func(s string) string {
		return strings.Map(func(r rune) rune {
			if r == '\n' || r == '\t' || unicode.IsPrint(r) {
				return r
			}
			return -1
		}, ansi.Strip(s))
	}
	var out strings.Builder
	start := 0
	for _, span := range sgr.FindAllStringIndex(raw, -1) {
		out.WriteString(clean(raw[start:span[0]]))
		out.WriteString(raw[span[0]:span[1]])
		start = span[1]
	}
	out.WriteString(clean(raw[start:]))
	return strings.ReplaceAll(out.String(), "\t", "    ") + "\x1b[0m"
}

func fit(text string, width int) string { return ansi.Truncate(text, max(0, width), "…") }
func pad(text string, width int) string {
	text = fit(text, width)
	return text + strings.Repeat(" ", max(0, width-ansi.StringWidth(text)))
}
func pair(left, right string, width int) string {
	right = fit(right, max(0, width/2))
	left = fit(left, max(0, width-ansi.StringWidth(right)-2))
	return left + strings.Repeat(" ", max(0, width-ansi.StringWidth(left)-ansi.StringWidth(right))) + right
}

func (m *model) panel(title, body string, width, height int) string {
	width = max(4, width)
	height = max(2, height)
	inner := width - 4
	title = fit(title, max(0, width-6))
	top := m.styles.border.Render("╭─ ") + m.styles.muted.Bold(true).Render(title) + m.styles.border.Render(" "+strings.Repeat("─", max(0, width-5-ansi.StringWidth(title)))+"╮")
	lines := strings.Split(body, "\n")
	out := []string{top}
	for i := 0; i < height-2; i++ {
		line := ""
		if i < len(lines) {
			line = lines[i]
		}
		out = append(out, m.styles.border.Render("│ ")+pad(line, inner)+m.styles.border.Render(" │"))
	}
	out = append(out, m.styles.border.Render("╰"+strings.Repeat("─", width-2)+"╯"))
	return strings.Join(out, "\n")
}

func (m *model) helpLines() []string {
	if m.sessionCreation() {
		keys := []string{"[/] 종류 전환", "Tab 필드 이동"}
		if m.folderEditing {
			keys = append(keys, "C-n/p·↑↓ 후보", "PgUp/Dn 페이지", "C-l 경로 완성", "Enter 선택", "C-Enter 선택+생성", "F5 갱신")
		} else {
			keys = append(keys, "C-o 폴더 변경", "Enter / C-Enter 생성")
		}
		return m.wrapHelp(append(keys, "Esc 취소"))
	}
	if m.folderEditing {
		if m.projectOpen {
			return []string{"C-n/p 또는 ↑/↓ 후보 이동 · Enter 선택 · Esc 목록 닫기"}
		}
		if len(m.folderChoices) > 0 {
			return []string{"C-n/p 또는 ↑/↓ 후보 이동 · C-l 완성 · C-o 프로젝트 찾기", "Enter 적용 (후보 선택 시 완성) · Esc 목록 닫기"}
		}
		return []string{"입력 시 폴더 후보 표시 · C-o 프로젝트 찾기", "Enter 적용 · Esc 돌아가기"}
	}
	if m.modal == "send" {
		return []string{"Enter 전송 (대상에 Enter 포함) · Esc 취소"}
	}
	if m.modal == "close" {
		return []string{"y 종료 · Enter / n / Esc 취소"}
	}
	if m.modal != "" && !m.creating() {
		return []string{"Enter 저장 · Esc 취소"}
	}
	group := "session"
	if m.mode == "workspaces" {
		group = "WS"
	}
	items := []string{"Enter 이동", "C-h/l・C-p/n " + group, "C-j/k 행", "C-o 접기/펼치기", "C-g 전체", "Tab/S-Tab pane", "C-u/d 스크롤", "C-s 입력", "C-a 추가", "C-r 이름", "C-x 종료", "C-/ 미리보기", "Esc 닫기"}
	if m.creating() {
		action := "Enter 생성"
		if m.creationFocus == 1 {
			action = "Enter 폴더 변경"
		}
		if m.creationFocus == 2 {
			action = "Space 종류 전환"
		}
		items = []string{"[/] 종류 전환", "Tab 필드 이동", "C-o 폴더 변경", action, "Esc 취소"}
	}
	if m.mode == "move-pane" {
		items = []string{"C-h/l・C-p/n 선택", "Enter 이동 후 따라가기", "C-Enter pane만 이동", "Esc 취소"}
	}
	if m.modal == "" && m.search.Value() != "" {
		for i := range items {
			if items[i] == "Esc 닫기" || items[i] == "Esc 취소" {
				items[i] = "Esc 검색 지우기"
			}
		}
	}
	return m.wrapHelp(items)
}

func (m *model) wrapHelp(items []string) []string {
	var lines []string
	line := ""
	for _, item := range items {
		next := item
		if line != "" {
			next = line + " · " + item
		}
		if ansi.StringWidth(next) > m.width-4 && line != "" {
			lines = append(lines, line)
			line = item
		} else {
			line = next
		}
	}
	return append(lines, line)
}

type dimensions struct {
	leftW, leftH, rightW, rightH int
	stack                        bool
}

func (m *model) dimensions() dimensions {
	w, h := max(20, m.width-2), max(10, m.height-len(m.helpLines())-2)

	if !m.showPreview || m.creating() {
		return dimensions{leftW: w, leftH: h}
	}
	if m.width < 90 {
		if h < 16 {
			return dimensions{leftW: w, leftH: h}
		}
		rightH := max(9, h*35/100)
		return dimensions{leftW: w, leftH: max(6, h-rightH-1), rightW: w, rightH: rightH, stack: true}
	}
	left := max(28, (w-2)*40/100)
	return dimensions{leftW: left, leftH: h, rightW: w - left - 2, rightH: h}
}
func (m *model) listHeight() int { return max(1, m.dimensions().leftH-5) }
func (m *model) resize() {
	d := m.dimensions()
	m.search.SetWidth(max(5, d.leftW-15))
	m.prompt.SetWidth(max(5, d.leftW-18))
	// Bubbles adds a trailing cursor cell beyond the configured input width.
	m.folderInput.SetWidth(max(5, d.leftW-5-ansi.StringWidth(m.folderInput.Prompt)))
	m.projectInput.SetWidth(max(5, d.leftW-5-ansi.StringWidth(m.projectInput.Prompt)))
	m.viewport.SetWidth(max(1, d.rightW-4))
	m.viewport.SetHeight(max(1, d.rightH-7))
}

func (m *model) highlighted(text, query string, style lipgloss.Style, selected bool) string {
	positions := map[int]bool{}
	chars := util.ToChars([]byte(text))
	for _, term := range strings.Fields(query) {
		if strings.ContainsAny(term, "!^$'|") {
			continue
		}
		sensitive := strings.IndexFunc(term, unicode.IsUpper) >= 0
		pattern := term
		if !sensitive {
			pattern = strings.ToLower(pattern)
		}
		_, pos := algo.FuzzyMatchV2(sensitive, true, true, &chars, []rune(pattern), true, nil)
		if pos != nil {
			for _, i := range *pos {
				positions[i] = true
			}
		}
	}
	var out strings.Builder
	for i, r := range []rune(text) {
		s := style
		if positions[i] {
			s = m.styles.amber
			if selected {
				s = s.Background(m.styles.selection)
			}
		}
		out.WriteString(s.Render(string(r)))
	}
	return out.String()
}

func (m *model) rowView(row tuios.Row, width int, selected bool) string {
	base, secondary, status, marker := m.styles.normal, m.styles.muted, m.styles.green, m.styles.pointer
	if row.Parent == "" {
		base = m.styles.bright
	}
	if selected {
		bg := m.styles.selection
		base = base.Background(bg)
		secondary = secondary.Background(bg)
		status = status.Background(bg)
		marker = marker.Background(bg)
	}
	label := row.Label
	if row.Kind == "workspace" && (label == "" || label == "이름 없음") {
		label = "—"
	}
	prefix := ""
	if row.Parent == "" && row.Kind != "new-workspace" {
		arrow := "▸"
		if m.expanded[row.ID] {
			arrow = "▾"
		}
		prefix = arrow + " "
		if row.Kind == "workspace" {
			prefix += fmt.Sprintf("%-2d  ", row.Number)
		}
	} else {
		prefix = "  └ "
		if row.Kind == "new-workspace" {
			prefix = ""
		}
		if row.Kind == "workspace" {
			label = fmt.Sprintf("%d  %s", row.Number, label)
			if m.mode == "sessions" && strings.TrimSpace(m.search.Value()) != "" {
				prefix = ""
				name := row.Label
				if name == "" || name == "이름 없음" {
					name = "—"
				}
				label = fmt.Sprintf("%s › %d %s", m.sessionLabel(row), row.Number, name)
			}
		}
	}
	hasVisibleChildren := false
	for _, child := range m.visible {
		if child.Parent == row.ID {
			hasVisibleChildren = true
			break
		}
	}
	hideSummary := row.Kind == "session" && m.expanded[row.ID] && hasVisibleChildren && strings.TrimSpace(m.search.Value()) == ""
	badge := row.Agents.Label()
	if hideSummary {
		badge = ""
	}
	if row.Agents.Done > 0 {
		status = m.styles.green
	} else if row.Agents.NeedsInput > 0 || row.Agents.Errored > 0 {
		status = m.styles.amber
	} else if row.Agents.Working > 0 {
		status = m.styles.pointer
	}
	if selected {
		status = status.Background(m.styles.selection)
	}
	if row.Current && !hideSummary {
		if badge != "" {
			badge += " · "
		}
		badge += "current"
	}
	command := ""
	if row.Command != "" {
		command = " │ " + row.Command
	}
	leftWidth := max(0, width-2)
	if badge != "" {
		badge = fit(badge, max(0, width/2))
		leftWidth = max(0, leftWidth-ansi.StringWidth(badge)-2)
	}
	label = fit(label, max(0, leftWidth-ansi.StringWidth(prefix)-ansi.StringWidth(command)))
	left := secondary.Render(prefix) + m.highlighted(label, m.search.Value(), base, selected) + secondary.Render(command)
	left = pad(left, leftWidth)
	if badge != "" {
		left += "  " + status.Render(badge)
	}
	line := "  " + left
	if selected {
		line = marker.Render("▌ ") + left
	}
	line = pad(line, width)
	if selected {
		return lipgloss.NewStyle().Background(m.styles.selection).Render(line)
	}
	return line
}

func (m *model) listView(width, height int) string {
	var lines []string
	if m.sessionCreation() {
		lines, _, _ = m.sessionCreationLines(width, height)
		return m.panel("새 session", strings.Join(lines, "\n"), width, height)
	}
	if m.folderEditing {
		input := m.folderInput.View()
		if m.projectOpen {
			input = m.projectInput.View()
		}
		lines = []string{"", input, ""}
		if m.projectLoading && m.projectOpen {
			lines = append(lines, m.styles.muted.Render("프로젝트 불러오는 중…"))
		} else if len(m.folderChoices) > 0 {
			capacity := max(1, height-7)
			start := max(0, m.folderChoiceIndex-capacity+1)
			for i := start; i < min(len(m.folderChoices), start+capacity); i++ {
				label := "  " + tuios.Clean(m.folderChoices[i].label)
				style := m.styles.normal
				if i == m.folderChoiceIndex {
					label = "› " + tuios.Clean(m.folderChoices[i].label)
					style = m.styles.pointer
				}
				lines = append(lines, style.Render(fit(label, width-4)))
			}
			if m.projectOpen {
				lines = append(lines, m.styles.muted.Render(fit(tuios.Clean(m.folderChoices[m.folderChoiceIndex].path), width-4)))
			}
		} else if m.projectOpen {
			lines = append(lines, m.styles.muted.Render("일치하는 프로젝트 없음"))
		} else {
			lines = append(lines, m.styles.muted.Render("이번 생성에 사용할 폴더"), m.styles.muted.Render("~/ 지원 · 상대 경로는 처음 제안된 폴더 기준"))
		}
	} else if m.creating() {
		root, child := "Session", "Workspace"
		if m.mode == "workspaces" {
			root, child = "Workspace", "Pane"
		}
		rootStyle, childStyle := m.styles.muted, m.styles.muted
		if m.modalRow.ID == "" {
			root, rootStyle = "[ "+root+" ]", m.styles.pointer.Bold(true)
		} else {
			child, childStyle = "[ "+child+" ]", m.styles.pointer.Bold(true)
		}
		marker := "종류  "
		if m.creationFocus == 2 {
			marker = "› 종류  "
		}
		lines = []string{m.styles.bright.Render(marker) + rootStyle.Render(root) + "   " + childStyle.Render(child)}
		if destination := m.creationDestination(); destination != "" {
			lines = append(lines, m.styles.muted.Render("소속  ")+m.styles.bright.Render(tuios.Clean(destination)))
		}
		lines = append(lines, "", m.prompt.View())
		path := m.creationFolder.Path
		if m.folderLoading {
			path = "확인 중…"
		} else if path == "" {
			path = "폴더를 지정하세요"
		}
		folderLabel := "시작 폴더"
		if m.creationFocus == 1 {
			folderLabel = "› " + folderLabel
		}
		lines = append(lines, "", m.styles.bright.Render(folderLabel))
		// Keep spaces in paths: Clean collapses them and would display a
		// different folder from the one actually passed to creation.
		path = strings.Map(func(r rune) rune {
			if unicode.IsPrint(r) {
				return r
			}
			return '�'
		}, path)
		lines = append(lines, strings.Split(ansi.Hardwrap(path, max(1, width-4), true), "\n")...)
		lines = append(lines, m.styles.muted.Render(fit(tuios.Clean(m.creationFolder.Source), width-4)))
		if m.creationChild.ID == "" {
			lines = append(lines, m.styles.muted.Render("하위 생성: 먼저 "+m.creationParentKind()+" 선택"))
		}
	} else if m.modal == "send" {
		lines = []string{m.styles.muted.Render("대상 workspace"), m.styles.bright.Render(fit(tuios.Clean(m.inputTarget), width-4)), m.styles.muted.Render("대상 pane"), m.styles.bright.Render(fit(tuios.Clean(m.modalRow.Label), width-4)), "", m.prompt.View(), "", m.styles.muted.Render("텍스트와 Enter를 보냅니다")}
	} else if m.modal != "" {
		lines = []string{"", m.prompt.View()}
	} else if m.loading && len(m.rows) == 0 {
		lines = []string{m.styles.muted.Render("불러오는 중…")}
	} else {
		end := min(len(m.visible), m.offset+height-2)
		for i := m.offset; i < end; i++ {
			lines = append(lines, m.rowView(m.visible[i], width-4, i == m.index))
		}
		if len(m.visible) == 0 {
			lines = append(lines, m.styles.muted.Render("검색 결과 없음"))
		}
	}
	title := "Sessions"
	if m.mode == "workspaces" {
		title = "Workspaces"
	}
	if m.mode == "move-pane" {
		title = "pane 이동: " + tuios.Clean(m.inputTarget)
	} else if m.folderEditing {
		title = "시작 폴더 변경"
	} else if m.creating() {
		title = "추가"
	} else if m.modal == "send" {
		title = "입력 보내기"
	}
	return m.panel(title, strings.Join(lines, "\n"), width, height)
}

func (m *model) previewView(width, height int) string {
	w := max(1, width-4)
	if len(m.preview.Panes) > 1 && !m.previewLoading {
		header := m.styles.muted.Render(fit(tuios.Clean(m.preview.Location), w))
		header += "\n" + m.styles.muted.Render(fit("● 입력 대상: "+tuios.Clean(strings.TrimPrefix(m.preview.Title, "● ")), w))
		body := m.styles.splitPreview(m.preview.Panes, m.preview.PaneID, w, max(1, height-5))
		return m.panel("Workspace preview", header+"\n\n"+body, width, height)
	}
	title, location := m.styles.bright.Render(tuios.Clean(m.preview.Title)), m.styles.muted.Render(tuios.Clean(m.preview.Location))
	if m.previewLoading {
		title = m.styles.muted.Render("불러오는 중…")
		location = ""
	}
	status := ""
	if m.preview.Current {
		status = m.styles.green.Render("current")
	}
	header := []string{"", pair(title, location, w), pair(m.styles.muted.Render(tuios.Clean(m.preview.Path)), status, w), m.styles.border.Render(strings.Repeat("─", w)), ""}
	panelTitle := "Preview"
	if m.preview.Overview {
		panelTitle = "Session overview"
	}
	return m.panel(panelTitle, strings.Join(header, "\n")+"\n"+m.viewport.View(), width, height)
}

func (m *model) View() tea.View {
	if m.modal == "close" || m.standalone {
		return m.closeView()
	}
	d := m.dimensions()
	input := m.search.View()
	total := len(filterRows(m.rows, m.expanded, ""))
	if m.mode == "sessions" && strings.TrimSpace(m.search.Value()) != "" {
		total = len(m.rows)
	}
	count := m.styles.muted.Render(fmt.Sprintf("%d/%d", len(m.visible), total))
	if m.modal != "" {
		heading := "이름 변경"
		if m.creating() {
			heading = "새 항목 만들기"
		} else if m.modal == "send" {
			heading = "입력 보내기"
		}
		input = m.styles.bright.Render(heading)
		count = ""
	}
	left := pair(input, count, d.leftW) + "\n" + m.styles.border.Render(strings.Repeat("─", d.leftW)) + "\n\n" + m.listView(d.leftW, d.leftH-3)
	body := left
	if m.showPreview && d.rightW > 0 {
		right := m.previewView(d.rightW, d.rightH)
		if d.stack {
			body = left + "\n\n" + right
		} else {
			body = lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right)
		}
	}
	status := m.status
	if m.loading {
		if status != "" {
			status += " · "
		}
		status += "목록 갱신 중…"
	}
	footer := m.styles.muted.Render(fit(tuios.Clean(status), max(0, m.width-2)))
	for _, line := range m.helpLines() {
		footer += "\n" + m.styles.normal.Render(line)
	}
	content := lipgloss.NewStyle().Padding(0, 1).Render(body + "\n" + footer)
	v := tea.NewView(content)
	v.AltScreen = true
	v.Cursor = m.inputCursor()
	return v
}

// Give the host a visible caret at the input, so IME composition can be
// displayed before the composed character is committed to the picker.
func (m *model) inputCursor() *tea.Cursor {
	input, x, y := m.search, 1, 0
	if m.modal != "" {
		if m.modal == "close" {
			return nil
		}
		input, x, y = m.prompt, 3, 5
		if m.sessionCreation() {
			d := m.dimensions()
			_, folderLine, nameLine := m.sessionCreationLines(d.leftW, d.leftH-3)
			if m.folderEditing {
				input = m.folderInput
				y = 4 + folderLine
			} else if m.creationFocus == 0 {
				y = 4 + nameLine
			} else {
				return nil
			}
		} else if m.folderEditing {
			input = m.folderInput
			if m.projectOpen {
				input = m.projectInput
			}
		} else if m.modal == "send" {
			y = 9
		} else if m.creating() {
			if m.creationFocus != 0 {
				return nil
			}
			y = 6
			if m.creationDestination() != "" {
				y++
			}
		}
	}
	c := input.Cursor()
	if c == nil {
		return nil
	}
	// Bubbles 2.2.1 Cursor uses a rune index and does not account for the
	// input's horizontal scroll. Locate its caret in an unstyled, static
	// rendering instead, keeping CJK width and the component's viewport.
	probe := input
	probe.SetVirtualCursor(true)
	probe.SetStyles(textinput.Styles{})
	marked := probe.View()
	if i := strings.Index(marked, "\x1b[7m"); i >= 0 {
		c.Position.X = ansi.StringWidth(marked[:i])
	}
	c.Position.X += x
	c.Position.Y += y
	if c.Position.X >= m.width || c.Position.Y >= m.height {
		return nil
	}
	return c
}
