package tuios

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func creationCwd() string {
	if cwd := os.Getenv("TUIOS_ACTIVE_PANE_CWD"); cwd != "" {
		return cwd
	}
	cwd, _ := os.Getwd()
	return cwd
}

// Always resolve the explicit parent. Never let the CLI fall back to the
// daemon's most recently active session when a selected parent disappears.
func (s *Service) creationTarget(row Row) (string, workspaceList, string, error) {
	target := row.Session
	if target == "" {
		if row.ID != "" {
			return "", workspaceList{}, "", fmt.Errorf("선택한 대상의 session을 확인하지 못했습니다")
		}
		target = s.Target
	}
	if target == "" {
		return "", workspaceList{}, "", fmt.Errorf("생성할 session을 확인하지 못했습니다")
	}
	if row.SessionID != "" {
		id, err := s.sessionID(target)
		if err != nil {
			return "", workspaceList{}, "", err
		}
		if id != row.SessionID {
			return "", workspaceList{}, "", fmt.Errorf("선택한 session이 변경되거나 종료되었습니다")
		}
	}
	var tabs workspaceList
	if err := s.command(&tabs, "list-workspaces", "-s", target); err != nil {
		return "", tabs, "", err
	}
	number := row.Number
	found := false
	for _, tab := range tabs.Items {
		if row.Kind == "workspace" && tab.Number == number && visible(tab) {
			found = true
		}
		if row.Kind != "workspace" && tab.Current {
			number = tab.Number
		}
	}
	if row.Kind == "workspace" && !found {
		return "", tabs, "", fmt.Errorf("선택한 workspace가 종료되었습니다")
	}
	var panes paneList
	if err := s.command(&panes, "list-windows", "-s", target); err != nil {
		return "", tabs, "", err
	}
	// Prefer a focused pane in the selected workspace, then any real pane in
	// that workspace, then another pane in the destination session.
	cwd, rank := "", -1
	for _, pane := range panes.Items {
		if pane.ID == s.Popup || pane.Cwd == "" {
			continue
		}
		r := 0
		if pane.Number == number {
			r = 1
			if pane.Focused {
				r = 2
			}
		}
		if r > rank {
			cwd, rank = pane.Cwd, r
		}
	}
	if cwd == "" {
		cwd = creationCwd()
	}
	return target, tabs, cwd, nil
}

// Match tuios-trial's policy: append after occupied slots, then reuse holes.
func nextWorkspaceSlot(tabs workspaceList) (int, error) {
	last := 0
	available := map[int]bool{}
	for _, tab := range tabs.Items {
		if tab.Number < 1 || tab.Number > 9 {
			continue
		}
		available[tab.Number] = !visible(tab)
		if visible(tab) {
			last = max(last, tab.Number)
		}
	}
	for n := last + 1; n <= 9; n++ {
		if available[n] {
			return n, nil
		}
	}
	for n := 1; n <= 9; n++ {
		if available[n] {
			return n, nil
		}
	}
	return 0, fmt.Errorf("추가할 빈 workspace가 없습니다 (최대 9개)")
}

func (s *Service) newShell(target string, number int, name, cwd string) (string, error) {
	ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
	defer cancel()
	out, err := s.run(ctx, "tuios", "new-window", "-s", target, name,
		"--workspace", strconv.Itoa(number), "--cwd", cwd, "--no-focus", "--print-id",
		"--", s.Trial, "app", "/bin/zsh")
	return strings.TrimSpace(string(out)), err
}

func (s *Service) createWorkspace(row Row, name string) (ActionResult, error) {
	target, tabs, cwd, err := s.creationTarget(row)
	if err != nil {
		return ActionResult{}, err
	}
	number, err := nextWorkspaceSlot(tabs)
	if err != nil {
		return ActionResult{}, err
	}
	if _, err := s.newShell(target, number, "shell", cwd); err != nil {
		return ActionResult{}, err
	}
	id := strconv.Itoa(number)
	if row.ID != "" {
		id = fmt.Sprintf("ws:%s:%d", row.ID, number)
	}
	result := ActionResult{Selected: id}
	ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
	defer cancel()
	if _, err := s.run(ctx, "tuios", "set-workspace-name", "-s", target, "--", strconv.Itoa(number), name); err != nil {
		result.Warning = fmt.Sprintf("workspace %d는 생성됐지만 이름 지정 실패: %v", number, err)
	}
	return result, nil
}

func (s *Service) createPane(row Row, name string) (ActionResult, error) {
	if row.Kind != "workspace" || row.ID == "" {
		return ActionResult{}, fmt.Errorf("pane을 추가할 workspace를 먼저 선택하세요")
	}
	target, _, cwd, err := s.creationTarget(row)
	if err != nil {
		return ActionResult{}, err
	}
	id, err := s.newShell(target, row.Number, name, cwd)
	if err != nil {
		return ActionResult{}, err
	}
	if id == "" || strings.ContainsAny(id, " \t\r\n") {
		return ActionResult{Warning: "pane은 생성됐지만 ID를 확인하지 못했습니다. 목록을 확인하세요"}, nil
	}
	return ActionResult{Selected: fmt.Sprintf("pane:%d:%s", row.Number, id)}, nil
}
