// Package tuios owns TUIOS identities, navigation and process lifetime. The UI
// works with rows and actions, never with herdr's inverted workspace/tab names.
package tuios

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
	"unicode"
)

type Row struct {
	ID, Parent, Kind, Label, Command, Session, SessionID string
	Number, Panes                                        int
	Current                                              bool
}

type Snapshot struct {
	Rows    []Row
	Current string
}

type ActionResult struct {
	Exit     bool
	Selected string
}

type Preview struct {
	Title, Path, Location, Screen string
	Current                       bool
}

type Service struct {
	ctx                                 context.Context
	cancel                              context.CancelFunc
	Target, Popup, Socket, State, Trial string
	run                                 func(context.Context, string, ...string) ([]byte, error)
	call                                func(string, any, any) error
	spawn                               func(...string) error
}

func New() *Service {
	socket := os.Getenv("TUIOS_SOCKET")
	if socket == "" {
		runtime := os.Getenv("XDG_RUNTIME_DIR")
		if runtime == "" {
			runtime = fmt.Sprintf("/tmp/tuios-%d", os.Getuid())
		}
		if os.Getenv("XDG_RUNTIME_DIR") != "" {
			runtime = filepath.Join(runtime, "tuios")
		}
		socket = filepath.Join(runtime, "tuios.sock")
	}
	home, _ := os.UserHomeDir()
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		state = filepath.Join(home, ".local", "state")
	}
	trial := os.Getenv("TUIOS_PICKER_TRIAL")
	if trial == "" {
		trial = "tuios-trial"
	}
	s := &Service{Target: os.Getenv("TUIOS_SESSION"), Popup: os.Getenv("TUIOS_WINDOW_ID"), Socket: socket,
		State: filepath.Join(state, "dotfiles-tuios"), Trial: trial}
	s.ctx, s.cancel = context.WithCancel(context.Background())
	s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		cmd := exec.CommandContext(ctx, name, args...)
		var stderr strings.Builder
		cmd.Stderr = &stderr
		out, err := cmd.Output()
		if err != nil {
			return nil, fmt.Errorf("%s: %w %s", name, err, Clean(stderr.String()))
		}
		return out, nil
	}
	s.call = s.rpc
	s.spawn = s.detach
	return s
}

// Stop in-flight CLI captures when the UI exits, including obsolete previews.
func (s *Service) Close() { s.cancel() }

// Native popup focus does not necessarily switch out of window management
// mode. Enter terminal mode before drawing, so the first typed key reaches us.
func (s *Service) PreparePopup() error {
	if os.Getenv("TUIOS_PICKER_POPUP") != "1" || s.Popup == "" || s.Target == "" {
		return nil
	}
	return s.command(nil, "run-command", "TerminalMode", "-s", s.Target)
}

func Clean(value string) string {
	return strings.Join(strings.Fields(strings.Map(func(r rune) rune {
		if unicode.IsPrint(r) || unicode.IsSpace(r) {
			return r
		}
		return -1
	}, value)), " ")
}

func (s *Service) rpc(method string, params, result any) error {
	c, err := net.DialTimeout("unix", s.Socket+".herdr", 5*time.Second)
	if err != nil {
		return err
	}
	defer c.Close()
	stop := context.AfterFunc(s.ctx, func() { _ = c.Close() })
	defer stop()
	_ = c.SetDeadline(time.Now().Add(20 * time.Second))
	if params == nil {
		params = map[string]any{}
	}
	if err = json.NewEncoder(c).Encode(map[string]any{"id": "dotfiles-picker", "method": method, "params": params}); err != nil {
		return err
	}
	var reply struct {
		Result json.RawMessage `json:"result"`
		Error  *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err = json.NewDecoder(bufio.NewReader(c)).Decode(&reply); err != nil {
		return err
	}
	if reply.Error != nil {
		return fmt.Errorf("%s", reply.Error.Message)
	}
	if result == nil {
		return nil
	}
	return json.Unmarshal(reply.Result, result)
}

func (s *Service) command(result any, args ...string) error {
	ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
	defer cancel()
	out, err := s.run(ctx, "tuios", append(args, "--json")...)
	if err != nil {
		return err
	}
	if result == nil {
		return nil
	}
	return json.Unmarshal(out, result)
}

type session struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Display    string `json:"display_name"`
	LastActive int64  `json:"last_active"`
}
type workspace struct {
	Number  int      `json:"workspace"`
	Name    string   `json:"name"`
	Count   int      `json:"window_count"`
	Current bool     `json:"current"`
	Focused string   `json:"focused_window_id"`
	History []string `json:"focus_history"`
}
type workspaceList struct {
	Items []workspace `json:"workspaces"`
	Order []int       `json:"order"`
}
type pane struct {
	ID      string `json:"window_id"`
	Number  int    `json:"workspace"`
	Custom  string `json:"custom_name"`
	Display string `json:"display_name"`
	Title   string `json:"title"`
	Command string `json:"foreground_cmd"`
	Cwd     string `json:"cwd"`
	Focused bool   `json:"focused"`
}
type paneList struct {
	Items []pane `json:"windows"`
	Shell string `json:"shell"`
}
type herdrWorkspace struct {
	ID    string `json:"workspace_id"`
	Label string `json:"label"`
	Count int    `json:"pane_count"`
}
type client struct {
	ID      string `json:"client_id"`
	Session string `json:"session"`
	PID     int    `json:"pid"`
}

func first(values ...string) string {
	for _, v := range values {
		if v != "" {
			return Clean(v)
		}
	}
	return ""
}
func opaque(id string) string { return "w" + strings.ReplaceAll(id, "-", "") }
func sessionFor(items []session, id string) (session, error) {
	for _, item := range items {
		if strings.HasPrefix(opaque(item.ID), id) {
			return item, nil
		}
	}
	return session{}, fmt.Errorf("이미 종료된 session입니다")
}
func (s *Service) sessionID(target string) (string, error) {
	var info struct {
		ID string `json:"session_id"`
	}
	if err := s.command(&info, "session-info", "-s", target); err != nil {
		return "", err
	}
	var result struct {
		Item herdrWorkspace `json:"workspace"`
	}
	err := s.call("workspace.get", map[string]any{"workspace_id": opaque(info.ID)}, &result)
	return result.Item.ID, err
}

func (s *Service) ClosePopup() {
	if s.Popup == "" || s.Target == "" {
		return
	}
	if os.Getenv("TUIOS_PICKER_POPUP") != "1" {
		var info pane
		if s.command(&info, "get-window", s.Popup, "-s", s.Target) != nil ||
			(info.Custom != "Fuzzy session 선택" && info.Custom != "Fuzzy workspace 선택") {
			return
		}
	}
	_ = s.call("pane.close", map[string]any{"pane_id": s.Popup}, nil)
}
