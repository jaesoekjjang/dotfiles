package main

import (
	"dotfiles/tuios-picker/internal/tuios"
	"github.com/charmbracelet/x/ansi"
	"strings"
)

// Scale window bounds, not terminal content. Crop each captured screen into
// its rectangle; no resize event is sent to any running terminal application.
func splitPreview(panes []tuios.PreviewPane, active string, width, height int) string {
	if width < 1 || height < 1 || len(panes) == 0 {
		return ""
	}
	minX, minY := panes[0].X, panes[0].Y
	maxX, maxY := minX+max(1, panes[0].Width), minY+max(1, panes[0].Height)
	for _, p := range panes {
		minX = min(minX, p.X)
		minY = min(minY, p.Y)
		maxX = max(maxX, p.X+max(1, p.Width))
		maxY = max(maxY, p.Y+max(1, p.Height))
	}
	canvas := make([]string, height)
	for i := range canvas {
		canvas[i] = strings.Repeat(" ", width)
	}
	// Preserve backend window ordering for overlapping/floating panes.
	for _, p := range panes {
		x := (p.X - minX) * width / max(1, maxX-minX)
		y := (p.Y - minY) * height / max(1, maxY-minY)
		right := (p.X + max(1, p.Width) - minX) * width / max(1, maxX-minX)
		bottom := (p.Y + max(1, p.Height) - minY) * height / max(1, maxY-minY)
		w, h := min(width-x, max(1, right-x)), min(height-y, max(1, bottom-y))
		if x < 0 || y < 0 || x >= width || y >= height {
			continue
		}
		lines := previewTile(p, p.ID == active, w, h)
		for j, line := range lines {
			if y+j >= height {
				break
			}
			canvas[y+j] = ansi.Cut(canvas[y+j], 0, x) + pad(line, w) + "\x1b[0m" + ansi.Cut(canvas[y+j], x+w, width)
		}
	}
	return strings.Join(canvas, "\n")
}
func previewTile(p tuios.PreviewPane, active bool, width, height int) []string {
	style := border
	if active {
		style = pointer
	}
	state := ""
	switch p.AgentState {
	case "done":
		state = "■ 완료 · "
	case "working":
		state = "● 작업 중 · "
	case "needs_input":
		state = "◆ 입력 대기 · "
	case "errored":
		state = "! 오류 · "
	}
	title := state + tuios.Clean(p.Title)
	if width < 4 || height < 3 {
		lines := make([]string, height)
		if height > 0 {
			lines[0] = style.Render(fit(title, width))
		}
		return lines
	}
	inner := width - 2
	lines := []string{style.Render("┌" + pad(fit(title, inner), inner) + "┐")}
	content := strings.Split(screenText(p.Screen), "\n")
	// Show the latest visible output when the scaled tile is shorter.
	start := max(0, len(content)-(height-2))
	for i := 0; i < height-2; i++ {
		text := ""
		if start+i < len(content) {
			text = content[start+i]
		}
		lines = append(lines, style.Render("│")+pad(ansi.Truncate(text, inner, ""), inner)+"\x1b[0m"+style.Render("│"))
	}
	return append(lines, style.Render("└"+strings.Repeat("─", inner)+"┘"))
}
