package main

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
	"github.com/junegunn/fzf/src/algo"
	"github.com/junegunn/fzf/src/util"
)

var (
	cyan    = lipgloss.Color("#7dcfff")
	normal  = lipgloss.NewStyle().Foreground(lipgloss.Color("#caced8"))
	bright  = lipgloss.NewStyle().Foreground(lipgloss.Color("#dcdfe6")).Bold(true)
	muted   = lipgloss.NewStyle().Foreground(lipgloss.Color("#a7adb7"))
	border  = lipgloss.NewStyle().Foreground(lipgloss.Color("#5c626c"))
	green   = lipgloss.NewStyle().Foreground(lipgloss.Color("#9ece6a"))
	pointer = lipgloss.NewStyle().Foreground(cyan)
	amber   = lipgloss.NewStyle().Foreground(lipgloss.Color("#e0af68"))
	sgr     = regexp.MustCompile("\x1b\\[[0-9;:]*m")
)

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

func panel(title, body string, width, height int) string {
	width = max(4, width)
	height = max(2, height)
	inner := width - 4
	title = fit(title, max(0, width-6))
	top := border.Render("╭─ ") + muted.Bold(true).Render(title) + border.Render(" "+strings.Repeat("─", max(0, width-5-ansi.StringWidth(title)))+"╮")
	lines := strings.Split(body, "\n")
	out := []string{top}
	for i := 0; i < height-2; i++ {
		line := ""
		if i < len(lines) {
			line = lines[i]
		}
		out = append(out, border.Render("│ ")+pad(line, inner)+border.Render(" │"))
	}
	out = append(out, border.Render("╰"+strings.Repeat("─", width-2)+"╯"))
	return strings.Join(out, "\n")
}

func (m *model) helpLines() []string {
	if m.modal == "close" {
		return []string{"y 종료 · Enter / n / Esc 취소"}
	}
	if m.modal != "" {
		return []string{"Enter 저장 · Esc 취소"}
	}
	group := "session"
	if m.mode == "workspaces" {
		group = "WS"
	}
	items := []string{"Enter 이동", "C-n/p 행", "C-j/k " + group, "Tab/C-o 펼침", "C-g 전체", "C-u/d 스크롤", "C-a 추가", "C-r 이름", "C-x 종료", "C-/ 미리보기", "Esc 닫기"}
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
	if !m.showPreview {
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
	m.viewport.SetWidth(max(1, d.rightW-4))
	m.viewport.SetHeight(max(1, d.rightH-7))
}

func highlighted(text, query string, style lipgloss.Style, selected bool) string {
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
			s = amber
			if selected {
				s = s.Background(lipgloss.Color("#383c45"))
			}
		}
		out.WriteString(s.Render(string(r)))
	}
	return out.String()
}

func (m *model) rowView(row tuios.Row, width int, selected bool) string {
	base, secondary, status, marker := normal, muted, green, pointer
	if row.Parent == "" {
		base = bright
	}
	if selected {
		bg := lipgloss.Color("#383c45")
		base = base.Background(bg)
		secondary = secondary.Background(bg)
		status = status.Background(bg)
		marker = marker.Background(bg)
	}
	label := row.Label
	prefix := ""
	if row.Parent == "" {
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
		if row.Kind == "workspace" {
			label = workspaceLabel(row)
			if m.mode == "sessions" && strings.TrimSpace(m.search.Value()) != "" {
				prefix = ""
				label = fmt.Sprintf("%s › %d %s", m.sessionLabel(row), row.Number, row.Label)
			}
		}
	}
	badge := ""
	if row.Current {
		badge = "current"
	}
	command := ""
	if row.Command != "" {
		command = " │ " + row.Command
	}
	leftWidth := max(0, width-2)
	if badge != "" {
		leftWidth = max(0, leftWidth-9)
	}
	label = fit(label, max(0, leftWidth-ansi.StringWidth(prefix)-ansi.StringWidth(command)))
	left := secondary.Render(prefix) + highlighted(label, m.search.Value(), base, selected) + secondary.Render(command)
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
		return lipgloss.NewStyle().Background(lipgloss.Color("#383c45")).Render(line)
	}
	return line
}

func (m *model) listView(width, height int) string {
	var lines []string
	if m.modal == "close" {
		row := m.modalRow
		label := row.Label
		if row.Kind == "workspace" {
			label = workspaceLabel(row)
			if m.mode == "sessions" && row.Parent != "" {
				label = m.sessionLabel(row) + " › " + label
			}
		}
		lines = []string{"", bright.Render(row.Kind + " '" + tuios.Clean(label) + "' 종료?"), "", muted.Render(fmt.Sprintf("%d panes", row.Panes)), "", amber.Render("y 종료"), muted.Render("Enter / n / Esc 취소")}
	} else if m.modal != "" {
		lines = []string{"", m.prompt.View(), "", muted.Render("Enter 저장 · Esc 취소")}
	} else if m.loading && len(m.rows) == 0 {
		lines = []string{muted.Render("불러오는 중…")}
	} else {
		end := min(len(m.visible), m.offset+height-2)
		for i := m.offset; i < end; i++ {
			lines = append(lines, m.rowView(m.visible[i], width-4, i == m.index))
		}
		if len(m.visible) == 0 {
			lines = append(lines, muted.Render("검색 결과 없음"))
		}
	}
	title := "Sessions"
	if m.mode == "workspaces" {
		title = "Workspaces"
	}
	return panel(title, strings.Join(lines, "\n"), width, height)
}

func (m *model) previewView(width, height int) string {
	w := max(1, width-4)
	title, location := bright.Render(tuios.Clean(m.preview.Title)), muted.Render(tuios.Clean(m.preview.Location))
	if m.previewLoading {
		title = muted.Render("불러오는 중…")
		location = ""
	}
	status := ""
	if m.preview.Current {
		status = green.Render("current")
	}
	header := []string{"", pair(title, location, w), pair(muted.Render(tuios.Clean(m.preview.Path)), status, w), border.Render(strings.Repeat("─", w)), ""}
	return panel("Preview", strings.Join(header, "\n")+"\n"+m.viewport.View(), width, height)
}

func (m *model) View() tea.View {
	d := m.dimensions()
	input := m.search.View()
	total := len(filterRows(m.rows, m.expanded, ""))
	if m.mode == "sessions" && strings.TrimSpace(m.search.Value()) != "" {
		total = len(m.rows)
	}
	count := muted.Render(fmt.Sprintf("%d/%d", len(m.visible), total))
	left := pair(input, count, d.leftW) + "\n" + border.Render(strings.Repeat("─", d.leftW)) + "\n\n" + m.listView(d.leftW, d.leftH-3)
	body := left
	if m.showPreview && d.rightW > 0 {
		right := m.previewView(d.rightW, d.rightH)
		if d.stack {
			body = left + "\n\n" + right
		} else {
			body = lipgloss.JoinHorizontal(lipgloss.Top, left, "  ", right)
		}
	}
	footer := muted.Render(fit(tuios.Clean(m.status), max(0, m.width-2)))
	for _, line := range m.helpLines() {
		footer += "\n" + normal.Render(line)
	}
	content := lipgloss.NewStyle().Padding(0, 1).Render(body + "\n" + footer)
	v := tea.NewView(content)
	v.AltScreen = true
	return v
}
