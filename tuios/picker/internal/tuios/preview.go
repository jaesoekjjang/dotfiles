package tuios

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"
)

func (s *Service) captureScreen(session, id string) (string, error) {
	if s.read != nil {
		var capture struct {
			Content string `json:"content"`
		}
		err := s.read("capture-pane", map[string]any{"session": session, "window": id, "ansi": true}, &capture)
		return strings.TrimRight(capture.Content, "\r\n"), err
	}
	ctx, cancel := context.WithTimeout(s.ctx, 5*time.Second)
	defer cancel()
	out, err := s.run(ctx, "tuios", "capture-pane", "-s", session, "-w", id, "--ansi")
	return strings.TrimRight(string(out), "\r\n"), err
}

// Read only: capture each pane without resizing it or changing its focus.
func (s *Service) captureLayout(session string, panes []pane) []PreviewPane {
	result := make([]PreviewPane, len(panes))
	jobs := make(chan int, len(panes))
	for i := range panes {
		jobs <- i
	}
	close(jobs)
	var workers sync.WaitGroup
	for range min(4, len(panes)) {
		workers.Go(func() {
			for i := range jobs {
				p := panes[i]
				screen, err := s.captureScreen(session, p.ID)
				if err != nil {
					screen = "(화면을 불러오지 못했습니다)"
				}
				result[i] = PreviewPane{ID: p.ID, Title: first(p.Custom, p.Display, p.Title, "pane"), Path: p.Cwd, Command: first(p.Command, "shell"), Current: p.Focused, Screen: screen, AgentState: p.AgentState, X: p.X, Y: p.Y, Width: p.Width, Height: p.Height}
			}
		})
	}
	workers.Wait()
	return result
}

func sessionOverview(title string, tabs workspaceList, panes paneList, popup string) Preview {
	var lines []string
	workspaces, total := 0, 0
	for _, tab := range ordered(tabs) {
		if !visible(tab) {
			continue
		}
		workspaces++
		heading := fmt.Sprintf("%d  %s", tab.Number, first(tab.Name, "—"))
		if tab.Current {
			heading += "  · 현재 workspace"
		}
		lines = append(lines, heading)
		count := 0
		for _, p := range panes.Items {
			if p.Number != tab.Number || p.ID == popup {
				continue
			}
			count++
			total++
			label := "  " + first(p.Custom, p.Display, p.Title, "pane")
			if state := agentCounts(p.AgentState).Label(); state != "" {
				label += "  · " + state
			}
			if p.Minimized {
				label += "  · 최소화"
			}
			lines = append(lines, label)
		}
		if count == 0 {
			lines = append(lines, "  (빈 workspace)")
		}
		lines = append(lines, "")
	}
	return Preview{Overview: true, Title: title, Path: fmt.Sprintf("%d workspaces · %d panes", workspaces, total), Screen: strings.Join(lines, "\n")}
}
