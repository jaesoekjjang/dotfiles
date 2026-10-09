package tuios

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

func ordered(data workspaceList) []workspace {
	items := slices.Clone(data.Items)
	rank := func(n int) int {
		i := slices.Index(data.Order, n)
		if i >= 0 {
			return i
		}
		return len(data.Order) + n
	}
	sort.SliceStable(items, func(i, j int) bool { return rank(items[i].Number) < rank(items[j].Number) })
	return items
}
func visible(w workspace) bool { return w.Current || w.Count > 0 || w.Name != "" }

func (s *Service) Snapshot(mode string) (Snapshot, error) {
	var snapshot Snapshot
	if mode == "sessions" {
		history, err := s.history("")
		if err != nil {
			return snapshot, err
		}
		var sessions []session
		if err = s.command(&sessions, "ls"); err != nil {
			return snapshot, err
		}
		var clients []client
		if err = s.command(&clients, "list-clients"); err != nil {
			return snapshot, err
		}
		var recent []string
		var attached []client
		for _, c := range clients {
			if c.Session == s.Target {
				attached = append(attached, c)
			}
		}
		if len(attached) == 1 {
			recent = history[strconv.Itoa(attached[0].PID)]
		}
		var data struct {
			Items []herdrWorkspace `json:"workspaces"`
		}
		if err = s.call("workspace.list", nil, &data); err != nil {
			return snapshot, err
		}
		current, err := s.sessionID(s.Target)
		if err != nil {
			return snapshot, err
		}
		snapshot.Current = current
		rank := func(w herdrWorkspace) (int, int64) {
			v, _ := sessionFor(sessions, w.ID)
			i := slices.Index(recent, v.ID)
			if i >= 0 {
				return i, 0
			}
			return len(recent), -v.LastActive
		}
		sort.SliceStable(data.Items, func(i, j int) bool {
			a, b := rank(data.Items[i])
			c, d := rank(data.Items[j])
			return a < c || a == c && b < d
		})
		for _, w := range data.Items {
			item, err := sessionFor(sessions, w.ID)
			if err != nil {
				continue
			}
			snapshot.Rows = append(snapshot.Rows, Row{ID: w.ID, Kind: "session", Label: first(w.Label, item.Display, item.Name), Session: item.Name, SessionID: w.ID, Panes: w.Count, Current: w.ID == current})
			var tabs workspaceList
			if err = s.command(&tabs, "list-workspaces", "-s", item.Name); err != nil {
				return snapshot, err
			}
			for _, tab := range ordered(tabs) {
				if tab.Count > 0 || w.ID == current && visible(tab) {
					snapshot.Rows = append(snapshot.Rows, Row{
						ID: fmt.Sprintf("ws:%s:%d", w.ID, tab.Number), Parent: w.ID, Kind: "workspace", Label: first(tab.Name, "이름 없음"),
						Session: item.Name, SessionID: w.ID, Number: tab.Number, Panes: tab.Count, Current: w.ID == current && tab.Current})
				}
			}
		}
	} else {
		var tabs workspaceList
		if err := s.command(&tabs, "list-workspaces", "-s", s.Target); err != nil {
			return snapshot, err
		}
		var panes paneList
		if err := s.command(&panes, "list-windows", "-s", s.Target); err != nil {
			return snapshot, err
		}
		for _, tab := range ordered(tabs) {
			if visible(tab) {
				id := strconv.Itoa(tab.Number)
				if tab.Current {
					snapshot.Current = id
				}
				snapshot.Rows = append(snapshot.Rows, Row{ID: id, Kind: "workspace", Label: tab.Name, Number: tab.Number, Session: s.Target, Panes: tab.Count, Current: tab.Current})
				for _, p := range panes.Items {
					if p.Number == tab.Number && p.ID != s.Popup {
						snapshot.Rows = append(snapshot.Rows, Row{
							ID: "pane:" + id + ":" + p.ID, Parent: id, Kind: "pane", Label: first(p.Custom, p.Display, p.Title, "pane"),
							Command: first(p.Command, "shell"), Session: s.Target, Number: tab.Number, Panes: 1, Current: p.Focused})
					}
				}
			}
		}
	}
	return snapshot, nil
}

func (s *Service) Preview(row Row) (Preview, error) {
	var result Preview
	var info struct {
		Display string `json:"display_name"`
	}
	if err := s.command(&info, "session-info", "-s", row.Session); err != nil {
		return result, err
	}
	var tabs workspaceList
	if err := s.command(&tabs, "list-workspaces", "-s", row.Session); err != nil {
		return result, err
	}
	var panes paneList
	if err := s.command(&panes, "list-windows", "-s", row.Session); err != nil {
		return result, err
	}
	var ws *workspace
	for i := range tabs.Items {
		w := &tabs.Items[i]
		if row.Kind == "session" && w.Current || row.Kind != "session" && w.Number == row.Number {
			ws = w
			break
		}
	}
	if ws == nil {
		return result, fmt.Errorf("이미 종료된 workspace입니다")
	}
	result.Location = fmt.Sprintf("%s › %d %s", first(info.Display, row.Session), ws.Number, first(ws.Name, "이름 없음"))
	var members []pane
	for _, p := range panes.Items {
		if p.Number == ws.Number && p.ID != s.Popup {
			members = append(members, p)
		}
	}
	var selected *pane
	find := func(id string) *pane {
		for i := range members {
			if members[i].ID == id {
				return &members[i]
			}
		}
		return nil
	}
	if row.Kind == "pane" {
		parts := strings.SplitN(row.ID, ":", 3)
		selected = find(parts[2])
		if selected == nil {
			return result, fmt.Errorf("이미 종료된 pane입니다")
		}
	} else {
		for _, id := range append([]string{ws.Focused}, ws.History...) {
			if selected = find(id); selected != nil {
				break
			}
		}
		if selected == nil {
			for i := range members {
				if members[i].Focused {
					selected = &members[i]
					break
				}
			}
		}
		if selected == nil && len(members) > 0 {
			selected = &members[0]
		}
	}
	if selected == nil {
		result.Title = result.Location
		result.Screen = "(빈 workspace)"
		return result, nil
	}
	result.Title = fmt.Sprintf("● %s  [%s]", first(selected.Custom, selected.Display, selected.Title, "pane"), first(selected.Command, panes.Shell, "shell"))
	result.Path = selected.Cwd
	home, _ := os.UserHomeDir()
	if result.Path == home || strings.HasPrefix(result.Path, home+"/") {
		result.Path = "~" + strings.TrimPrefix(result.Path, home)
	}
	result.Current = selected.Focused
	ctx, cancel := context.WithTimeout(s.ctx, 5*time.Second)
	defer cancel()
	out, err := s.run(ctx, "tuios", "capture-pane", "-s", row.Session, "-w", selected.ID, "--ansi")
	// Capture output is terminal text. Keep SGR colors but strip cursor, OSC and
	// other controls in the UI before rendering it inside our own screen.
	result.Screen = strings.TrimRight(string(out), "\r\n")
	return result, err
}

// Act reports whether to exit or which created row to select. A self-close is detached so
// TUIOS killing the popup cannot kill the operation halfway through.
func (s *Service) Act(action string, row Row, name string) (ActionResult, error) {
	switch action {
	case "enter":
		if row.Kind == "pane" {
			return ActionResult{Exit: true}, s.command(nil, "focus-window", strings.SplitN(row.ID, ":", 3)[2], "-s", row.Session)
		}
		if row.Kind == "workspace" {
			if err := s.command(nil, "select-workspace", strconv.Itoa(row.Number), "-s", row.Session); err != nil {
				return ActionResult{}, err
			}
			if row.Parent == "" {
				return ActionResult{Exit: true}, nil
			}
		}
		return ActionResult{Exit: true}, s.call("workspace.focus", map[string]any{"workspace_id": row.SessionID}, nil)
	case "rename":
		if strings.TrimSpace(name) == "" {
			return ActionResult{}, nil
		}
		if row.Kind == "session" {
			return ActionResult{}, s.call("workspace.rename", map[string]any{"workspace_id": row.ID, "label": name}, nil)
		}
		if row.Kind == "pane" {
			return ActionResult{}, s.call("pane.rename", map[string]any{"pane_id": strings.SplitN(row.ID, ":", 3)[2], "label": name}, nil)
		}
		// set-workspace-name is one of the CLI verbs without a --json flag.
		ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
		defer cancel()
		_, err := s.run(ctx, "tuios", "set-workspace-name", strconv.Itoa(row.Number), name, "-s", row.Session)
		return ActionResult{}, err
	case "create-session":
		var created struct {
			Item herdrWorkspace `json:"workspace"`
		}
		cwd := os.Getenv("TUIOS_ACTIVE_PANE_CWD")
		if cwd == "" {
			cwd, _ = os.Getwd()
		}
		if err := s.call("workspace.create", map[string]any{"label": name, "cwd": cwd, "focus": false}, &created); err != nil {
			return ActionResult{}, err
		}
		return ActionResult{Selected: created.Item.ID}, nil
	case "create-workspace":
		ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
		defer cancel()
		out, err := s.run(ctx, s.Trial, "new-workspace", name, "--no-focus")
		if err != nil {
			return ActionResult{}, err
		}
		id := strings.TrimSpace(string(out))
		number, err := strconv.Atoi(id)
		if err != nil || number < 1 || number > 9 {
			return ActionResult{}, fmt.Errorf("새 workspace 번호를 확인하지 못했습니다: %q", id)
		}
		return ActionResult{Selected: id}, nil
	case "close":
		if row.Kind == "pane" {
			return ActionResult{}, s.call("pane.close", map[string]any{"pane_id": strings.SplitN(row.ID, ":", 3)[2]}, nil)
		}
		current := ""
		if row.Kind == "session" {
			var err error
			current, err = s.sessionID(s.Target)
			if err != nil {
				return ActionResult{}, err
			}
		} else {
			var data workspaceList
			if err := s.command(&data, "list-workspaces", "-s", row.Session); err != nil {
				return ActionResult{}, err
			}
			for _, w := range data.Items {
				if w.Current {
					current = strconv.Itoa(w.Number)
				}
			}
		}
		selected := row.ID
		if row.Kind == "workspace" {
			selected = strconv.Itoa(row.Number)
		}
		self := row.Kind == "session" && selected == current || row.Kind == "workspace" && row.Session == s.Target && selected == current
		if self {
			return ActionResult{Exit: true}, s.spawn("_close", row.Kind, selected, current, row.Session)
		}
		return ActionResult{}, s.FinishClose(row.Kind, selected, current, row.Session)
	}
	return ActionResult{}, fmt.Errorf("알 수 없는 동작: %s", action)
}

func (s *Service) detach(args ...string) error {
	if err := os.MkdirAll(s.State, 0700); err != nil {
		return err
	}
	log, err := os.OpenFile(filepath.Join(s.State, "close.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer log.Close()
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command(executable, args...)
	cmd.Stdout = log
	cmd.Stderr = log
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err = cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}

func (s *Service) FinishClose(kind, selected, current, target string) error {
	if kind == "session" {
		if selected == current {
			var data struct {
				Items []herdrWorkspace `json:"workspaces"`
			}
			if err := s.call("workspace.list", nil, &data); err != nil {
				return err
			}
			index := slices.IndexFunc(data.Items, func(w herdrWorkspace) bool { return w.ID == current })
			if index < 0 {
				return fmt.Errorf("이미 종료된 session입니다")
			}
			others := append(slices.Clone(data.Items[index+1:]), data.Items[:index]...)
			if len(others) > 0 {
				var sessions []session
				if err := s.command(&sessions, "ls"); err != nil {
					return err
				}
				destination, err := sessionFor(sessions, others[0].ID)
				if err != nil {
					return err
				}
				var clients []client
				if err = s.command(&clients, "list-clients"); err != nil {
					return err
				}
				clients = slices.DeleteFunc(clients, func(c client) bool { return c.Session != target })
				if len(clients) > 1 {
					return fmt.Errorf("현재 세션에 여러 client가 연결되어 있어 자동 이동할 client를 정할 수 없습니다")
				}
				if len(clients) == 1 {
					id := clients[0].ID
					if err = s.command(nil, "switch-session", destination.Name, "--client", id); err != nil {
						return err
					}
					deadline := time.Now().Add(10 * time.Second)
					for {
						var live []client
						if err = s.command(&live, "list-clients"); err != nil {
							return err
						}
						if slices.ContainsFunc(live, func(c client) bool { return c.ID == id && c.Session == destination.Name }) {
							break
						}
						if time.Now().After(deadline) {
							return fmt.Errorf("다른 세션으로 이동하지 못해 현재 세션 종료를 취소했습니다")
						}
						time.Sleep(50 * time.Millisecond)
					}
				}
			}
		}
		return s.call("workspace.close", map[string]any{"workspace_id": selected}, nil)
	}
	id, err := s.sessionID(target)
	if err != nil {
		return err
	}
	var tabs struct {
		Items []struct {
			Number int    `json:"number"`
			ID     string `json:"tab_id"`
		} `json:"tabs"`
	}
	if err = s.call("tab.list", map[string]any{"workspace_id": id}, &tabs); err != nil {
		return err
	}
	for _, tab := range tabs.Items {
		if strconv.Itoa(tab.Number) == selected {
			return s.call("tab.close", map[string]any{"tab_id": tab.ID}, nil)
		}
	}
	return fmt.Errorf("이미 종료된 workspace입니다")
}

func (s *Service) Current(mode string) (Row, error) {
	if mode == "session" {
		id, err := s.sessionID(s.Target)
		if err != nil {
			return Row{}, err
		}
		var data struct {
			Item herdrWorkspace `json:"workspace"`
		}
		err = s.call("workspace.get", map[string]any{"workspace_id": id}, &data)
		return Row{ID: id, Kind: "session", Session: s.Target, SessionID: id, Label: first(data.Item.Label, s.Target), Panes: data.Item.Count, Current: true}, err
	}
	var data workspaceList
	if err := s.command(&data, "list-workspaces", "-s", s.Target); err != nil {
		return Row{}, err
	}
	for _, w := range data.Items {
		if w.Current {
			return Row{ID: strconv.Itoa(w.Number), Kind: "workspace", Session: s.Target, Number: w.Number, Label: first(w.Name, strconv.Itoa(w.Number)), Panes: w.Count, Current: true}, nil
		}
	}
	return Row{}, fmt.Errorf("현재 workspace를 찾을 수 없습니다")
}

func (s *Service) Cycle(step int) error {
	var data workspaceList
	if err := s.command(&data, "list-workspaces", "-s", s.Target); err != nil {
		return err
	}
	items := slices.DeleteFunc(ordered(data), func(w workspace) bool { return !visible(w) })
	i := slices.IndexFunc(items, func(w workspace) bool { return w.Current })
	if i < 0 {
		return fmt.Errorf("현재 workspace를 찾을 수 없습니다")
	}
	if len(items) < 2 {
		return nil
	}
	return s.command(nil, "select-workspace", strconv.Itoa(items[(i+step+len(items))%len(items)].Number), "-s", s.Target)
}

// The file format and socket hash are shared with the former Python picker, so
// upgrading does not discard per-client session history.
func (s *Service) history(target string) (map[string][]string, error) {
	if err := os.MkdirAll(s.State, 0700); err != nil {
		return nil, err
	}
	key := os.Getenv("TUIOS_SOCKET")
	if key == "" {
		key = "default"
	}
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(key)))[:16]
	base := filepath.Join(s.State, "session-history-"+hash)
	lock, err := os.OpenFile(base+".lock", os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return nil, err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return nil, err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	var sessions []session
	if err = s.command(&sessions, "ls"); err != nil {
		return nil, err
	}
	byName, byID := map[string]string{}, map[string]string{}
	for _, item := range sessions {
		byName[item.Name] = item.ID
		byID[item.ID] = item.Name
	}
	var clients []client
	if err = s.command(&clients, "list-clients"); err != nil {
		return nil, err
	}
	old := map[string][]string{}
	bytes, readErr := os.ReadFile(base + ".json")
	if readErr != nil && !os.IsNotExist(readErr) {
		return nil, readErr
	}
	_ = json.Unmarshal(bytes, &old)
	live := map[string][]string{}
	var matches []client
	for _, c := range clients {
		current, ok := byName[c.Session]
		if !ok {
			continue
		}
		pid := strconv.Itoa(c.PID)
		recent := []string{current}
		for _, id := range old[pid] {
			if id != current && byID[id] != "" && len(recent) < 20 && !slices.Contains(recent, id) {
				recent = append(recent, id)
			}
		}
		live[pid] = recent
		if c.Session == target {
			matches = append(matches, c)
		}
	}
	bytes, err = json.Marshal(live)
	if err != nil {
		return nil, err
	}
	if err = os.WriteFile(base+".tmp", bytes, 0600); err != nil {
		return nil, err
	}
	if err = os.Rename(base+".tmp", base+".json"); err != nil {
		return nil, err
	}
	if target != "" {
		if len(matches) != 1 {
			return nil, fmt.Errorf("직전 세션 이동에는 현재 세션에 연결된 client가 하나여야 합니다")
		}
		c := matches[0]
		recent := live[strconv.Itoa(c.PID)]
		if len(recent) > 1 {
			err = s.command(nil, "switch-session", byID[recent[1]], "--client", c.ID)
		}
	}
	return live, err
}
func (s *Service) Record() error { _, err := s.history(""); return err }
func (s *Service) Last() error   { _, err := s.history(s.Target); return err }
