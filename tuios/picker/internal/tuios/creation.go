package tuios

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
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
func (s *Service) creationTarget(row Row) (string, workspaceList, error) {
	target := row.Session
	if target == "" {
		if row.ID != "" {
			return "", workspaceList{}, fmt.Errorf("선택한 대상의 session을 확인하지 못했습니다")
		}
		target = s.Target
	}
	if target == "" {
		return "", workspaceList{}, fmt.Errorf("생성할 session을 확인하지 못했습니다")
	}
	if row.SessionID != "" {
		id, err := s.sessionID(target)
		if err != nil {
			return "", workspaceList{}, err
		}
		if id != row.SessionID {
			return "", workspaceList{}, fmt.Errorf("선택한 session이 변경되거나 종료되었습니다")
		}
	}
	var tabs workspaceList
	if err := s.command(&tabs, "list-workspaces", "-s", target); err != nil {
		return "", tabs, err
	}
	if row.Kind == "workspace" {
		found := false
		for _, tab := range tabs.Items {
			if tab.Number == row.Number && visible(tab) {
				found = true
			}
		}
		if !found {
			return "", tabs, fmt.Errorf("선택한 workspace가 종료되었습니다")
		}
	}
	return target, tabs, nil
}

type CreationFolder struct{ Path, Source string }

// Resolve the suggested folder once, from the selected context. A picker
// popup is never a source, and an empty workspace never borrows another one.
func (s *Service) CreationFolder(row Row) (CreationFolder, error) {
	if row.ID == "" {
		return CreationFolder{Path: creationCwd(), Source: "picker를 연 작업 폴더"}, nil
	}
	target, tabs, err := s.creationTarget(row)
	if err != nil {
		return CreationFolder{}, err
	}
	var ws *workspace
	for i := range tabs.Items {
		w := &tabs.Items[i]
		if (row.Kind == "session" && w.Current) || (row.Kind != "session" && w.Number == row.Number) {
			ws = w
			break
		}
	}
	var panes paneList
	if err := s.command(&panes, "list-windows", "-s", target); err != nil {
		return CreationFolder{}, err
	}
	if ws != nil {
		ids := append([]string{ws.Focused}, ws.History...)
		if row.Kind == "pane" {
			parts := strings.SplitN(row.ID, ":", 3)
			if len(parts) != 3 {
				return CreationFolder{}, fmt.Errorf("선택한 pane을 확인하지 못했습니다")
			}
			ids = []string{parts[2]}
		} else {
			for _, p := range panes.Items {
				if p.Focused {
					ids = append(ids, p.ID)
				}
			}
			for _, p := range panes.Items {
				ids = append(ids, p.ID)
			}
		}
		for _, id := range ids {
			for _, p := range panes.Items {
				if p.ID == id && p.ID != s.Popup && p.Number == ws.Number && p.Cwd != "" {
					return CreationFolder{Path: p.Cwd, Source: fmt.Sprintf("%s · %s에서 가져옴", first(ws.Name, strconv.Itoa(ws.Number)), first(p.Custom, p.Display, p.Title, "pane"))}, nil
				}
			}
		}
	}
	home, err := os.UserHomeDir()
	return CreationFolder{Path: home, Source: "작업 폴더를 찾지 못해 홈 폴더 사용"}, err
}

// Resolve paths without shell expansion. Relative paths use the folder shown
// when the form opened, never the daemon's cwd or a pane that has since cd'd.
func ResolveCreationFolder(value, base string) (string, error) {
	if strings.TrimSpace(value) == "" {
		return "", fmt.Errorf("시작 폴더를 입력하세요")
	}
	if strings.ContainsAny(value, "\x00\r\n") {
		return "", fmt.Errorf("폴더 경로는 한 줄로 입력하세요")
	}
	if value == "~" || strings.HasPrefix(value, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		value = filepath.Join(home, strings.TrimPrefix(value, "~"))
	}
	if !filepath.IsAbs(value) {
		if !filepath.IsAbs(base) {
			return "", fmt.Errorf("절대 경로나 ~/로 시작하는 경로를 입력하세요")
		}
		value = filepath.Join(base, value)
	}
	value = filepath.Clean(value)
	info, err := os.Stat(value)
	if err != nil {
		return "", fmt.Errorf("시작 폴더를 열 수 없습니다: %s", value)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("폴더가 아닙니다: %s", value)
	}
	return value, nil
}

func (s *Service) Create(action string, row Row, name, folder string) (ActionResult, error) {
	cwd, err := ResolveCreationFolder(folder, "")
	if err != nil {
		return ActionResult{}, err
	}
	switch action {
	case "create-session":
		var created struct {
			Item herdrWorkspace `json:"workspace"`
		}
		if err := s.call("workspace.create", map[string]any{"label": name, "cwd": cwd, "focus": false}, &created); err != nil {
			return ActionResult{}, err
		}
		return ActionResult{Selected: created.Item.ID}, nil
	case "create-workspace":
		return s.createWorkspace(row, name, cwd)
	case "create-pane":
		return s.createPane(row, name, cwd)
	}
	return ActionResult{}, fmt.Errorf("알 수 없는 생성 종류: %s", action)
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

func (s *Service) createWorkspace(row Row, name, cwd string) (ActionResult, error) {
	target, tabs, err := s.creationTarget(row)
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

func (s *Service) createPane(row Row, name, cwd string) (ActionResult, error) {
	if row.Kind != "workspace" || row.ID == "" {
		return ActionResult{}, fmt.Errorf("pane을 추가할 workspace를 먼저 선택하세요")
	}
	target, _, err := s.creationTarget(row)
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
