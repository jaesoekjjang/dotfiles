package tuios

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"
)

type harness struct {
	s       *Service
	events  []string
	tabs    map[string]string
	panes   string
	clients string
	spawned []string
}

func fixture(t *testing.T) *harness {
	t.Helper()
	h := &harness{s: New(), tabs: map[string]string{
		"source":      `{"order":[2,1],"workspaces":[{"workspace":1,"name":"dev","window_count":2,"current":true,"focused_window_id":"popup","focus_history":["popup","editor"]},{"workspace":2,"name":"logs","window_count":1,"focus_history":["log"]},{"workspace":3,"name":"","window_count":0}]}`,
		"destination": `{"workspaces":[{"workspace":1,"name":"other","window_count":1,"current":true}]}`,
	}, panes: `{"shell":"zsh","windows":[{"window_id":"popup","workspace":1,"custom_name":"picker","focused":true},{"window_id":"editor","workspace":1,"custom_name":"Editor","foreground_cmd":"nvim","cwd":"/tmp/project"},{"window_id":"log","workspace":2,"title":"Logs","foreground_cmd":"tail"}]}`,
		clients: `[{"client_id":"c1","pid":10,"session":"source"}]`}
	h.s.Target = "source"
	t.Cleanup(h.s.Close)
	h.s.Popup = "popup"
	h.s.State = t.TempDir()
	h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		h.events = append(h.events, strings.Join(append([]string{name}, args...), " "))
		if name != "tuios" {
			return []byte("{}"), nil
		}
		target := "source"
		for i, v := range args {
			if v == "-s" {
				target = args[i+1]
			}
		}
		out := "{}"
		switch args[0] {
		case "set-workspace-name":
			if slices.Contains(args, "--json") {
				return nil, fmt.Errorf("unknown flag: --json")
			}
		case "ls":
			out = `[{"id":"aa","name":"source","display_name":"Project","last_active":10},{"id":"bb","name":"destination","display_name":"Other","last_active":20}]`
		case "list-clients":
			out = h.clients
		case "session-info":
			if target == "source" {
				out = `{"session_id":"aa","display_name":"Project"}`
			} else {
				out = `{"session_id":"bb","display_name":"Other"}`
			}
		case "list-workspaces":
			out = h.tabs[target]
		case "list-windows":
			out = h.panes
		case "get-window":
			out = `{"custom_name":"ordinary shell"}`
		case "capture-pane":
			out = "\x1b[31mactual screen\x1b[0m\n"
		case "switch-session":
			h.clients = fmt.Sprintf(`[{"client_id":"c1","pid":10,"session":%q}]`, args[1])
		}
		return []byte(out), nil
	}
	h.s.call = func(method string, params, result any) error {
		p, _ := json.Marshal(params)
		h.events = append(h.events, method+" "+string(p))
		out := "{}"
		switch method {
		case "workspace.list":
			out = `{"workspaces":[{"workspace_id":"waa","label":"Project","pane_count":2},{"workspace_id":"wbb","label":"Other","pane_count":1}]}`
		case "workspace.get":
			id := params.(map[string]any)["workspace_id"]
			out = fmt.Sprintf(`{"workspace":{"workspace_id":%q,"label":"Project","pane_count":2}}`, id)
		case "workspace.create":
			out = `{"workspace":{"workspace_id":"wcc"}}`
		case "tab.list":
			out = `{"tabs":[{"number":1,"tab_id":"t1"},{"number":2,"tab_id":"t2"}]}`
		}
		if result != nil {
			return json.Unmarshal([]byte(out), result)
		}
		return nil
	}
	h.s.spawn = func(args ...string) error { h.spawned = slices.Clone(args); return nil }
	return h
}
func has(events []string, part string) bool {
	return slices.ContainsFunc(events, func(e string) bool { return strings.Contains(e, part) })
}

func TestSnapshotOrderingPopupExclusionAndCurrent(t *testing.T) {
	h := fixture(t)
	data, err := h.s.Snapshot("workspaces")
	if err != nil {
		t.Fatal(err)
	}
	var ids []string
	for _, r := range data.Rows {
		ids = append(ids, r.ID)
	}
	if !reflect.DeepEqual(ids, []string{"2", "pane:2:log", "1", "pane:1:editor"}) || data.Current != "1" {
		t.Fatalf("%v", data)
	}
	data, err = h.s.Snapshot("sessions")
	if err != nil {
		t.Fatal(err)
	}
	if data.Rows[0].ID != "waa" {
		t.Fatal("current client MRU before daemon activity")
	}
	for _, r := range data.Rows {
		if r.Session == "destination" && r.Current {
			t.Fatal("inactive session workspace must not say current")
		}
	}
}
func TestPreviewSelectsLastRealPaneAndExplicitPane(t *testing.T) {
	h := fixture(t)
	for _, r := range []Row{
		{Kind: "workspace", Number: 1, Session: "source"},
		{Kind: "session", Session: "source"},
		{ID: "pane:1:editor", Kind: "pane", Number: 1, Session: "source"},
	} {
		p, err := h.s.Preview(r)
		if err != nil {
			t.Fatal(err)
		}
		if p.Title != "● Editor  [nvim]" || p.Location != "Project › 1 dev" || !strings.Contains(p.Screen, "\x1b[31mactual screen") {
			t.Fatalf("%+v", p)
		}
		if !has(h.events, "-w editor --ansi") {
			t.Fatal("captured own popup")
		}
	}
	if _, err := h.s.Preview(Row{ID: "pane:1:gone", Kind: "pane", Number: 1, Session: "source"}); err == nil {
		t.Fatal("missing pane")
	}
	h.panes = `{"windows":[]}`
	p, err := h.s.Preview(Row{Kind: "workspace", Number: 1, Session: "source"})
	if err != nil || !strings.Contains(p.Screen, "빈 workspace") {
		t.Fatalf("%+v %v", p, err)
	}
}
func TestChildNavigationSelectsDestinationBeforeSessionFocus(t *testing.T) {
	h := fixture(t)
	exit, err := h.s.Act("enter", Row{ID: "ws:wbb:1", Parent: "wbb", Kind: "workspace", Session: "destination", SessionID: "wbb", Number: 1}, "")
	if err != nil || !exit.Exit {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(h.events, []string{"tuios select-workspace 1 -s destination --json", `workspace.focus {"workspace_id":"wbb"}`}) {
		t.Fatal(h.events)
	}
}
func TestCloseTargetsEveryRowType(t *testing.T) {
	for _, tc := range []struct {
		name     string
		row      Row
		want     string
		detached bool
	}{
		{"pane", Row{ID: "pane:1:editor", Kind: "pane", Session: "source"}, `pane.close {"pane_id":"editor"}`, false},
		{"noncurrent workspace", Row{ID: "2", Kind: "workspace", Session: "source", Number: 2}, `tab.close {"tab_id":"t2"}`, false},
		{"session child workspace", Row{ID: "ws:wbb:1", Parent: "wbb", Kind: "workspace", Session: "destination", Number: 1}, `tab.close {"tab_id":"t1"}`, false},
		{"noncurrent session", Row{ID: "wbb", Kind: "session", Session: "destination"}, `workspace.close {"workspace_id":"wbb"}`, false},
		{"current session", Row{ID: "waa", Kind: "session", Session: "source"}, "session", true},
		{"current workspace", Row{ID: "ws:waa:1", Parent: "waa", Kind: "workspace", Session: "source", Number: 1}, "workspace", true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			h := fixture(t)
			exit, err := h.s.Act("close", tc.row, "")
			if err != nil {
				t.Fatal(err)
			}
			if exit.Exit != tc.detached {
				t.Fatal("exit state")
			}
			if tc.detached {
				if len(h.spawned) != 5 || h.spawned[1] != tc.want {
					t.Fatal(h.spawned)
				}
			} else if !has(h.events, tc.want) {
				t.Fatal(h.events)
			}
			if tc.row.Kind != "session" && has(h.events, "workspace.close") {
				t.Fatal("closed parent session")
			}
		})
	}
}
func TestCurrentSessionSwitchCompletesBeforeClose(t *testing.T) {
	h := fixture(t)
	if err := h.s.FinishClose("session", "waa", "waa", "source"); err != nil {
		t.Fatal(err)
	}
	switchAt, closeAt := -1, -1
	for i, e := range h.events {
		if strings.Contains(e, "switch-session destination") {
			switchAt = i
		}
		if strings.Contains(e, "workspace.close") {
			closeAt = i
		}
	}
	if switchAt < 0 || closeAt <= switchAt+1 {
		t.Fatal("must observe destination attach before close", h.events)
	}
	h = fixture(t)
	h.clients = `[{"client_id":"c1","session":"source"},{"client_id":"c2","session":"source"}]`
	if err := h.s.FinishClose("session", "waa", "waa", "source"); err == nil || has(h.events, "workspace.close") {
		t.Fatal("ambiguous clients must preserve session")
	}
}
func TestSessionHistoryRoundTripAndDeletedEntries(t *testing.T) {
	h := fixture(t)
	if err := h.s.Record(); err != nil {
		t.Fatal(err)
	}
	h.clients = `[{"client_id":"c1","pid":10,"session":"destination"}]`
	if err := h.s.Record(); err != nil {
		t.Fatal(err)
	}
	h.s.Target = "destination"
	if err := h.s.Last(); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "switch-session source --client c1") {
		t.Fatal(h.events)
	}
	files, _ := filepath.Glob(filepath.Join(h.s.State, "*.json"))
	raw, err := os.ReadFile(files[0])
	if err != nil {
		t.Fatal(err)
	}
	var history map[string][]string
	if err = json.Unmarshal(raw, &history); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(history["10"], []string{"bb", "aa"}) {
		t.Fatal(history)
	}
	if err = os.WriteFile(files[0], []byte(`{"10":["bb","gone","aa","aa"]}`), 0600); err != nil {
		t.Fatal(err)
	}
	live, err := h.s.history("")
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(live["10"], []string{"aa", "bb"}) {
		t.Fatal(live)
	}
}
func TestRenameIdentityCreateCwdAndWorkspaceCycle(t *testing.T) {
	h := fixture(t)
	t.Setenv("TUIOS_ACTIVE_PANE_CWD", "/project with spaces")
	h.s.Act("rename", Row{ID: "waa", Kind: "session"}, "Renamed")
	if !has(h.events, `workspace.rename {"label":"Renamed","workspace_id":"waa"}`) {
		t.Fatal(h.events)
	}
	if _, err := h.s.Act("rename", Row{ID: "2", Kind: "workspace", Number: 2, Session: "source"}, "New name"); err != nil {
		t.Fatal(err)
	}
	n := len(h.events)
	h.s.Act("rename", Row{ID: "ws:waa:1", Parent: "waa", Kind: "workspace"}, "ignored")
	if len(h.events) != n {
		t.Fatal("child rename")
	}
	result, err := h.s.Act("create-session", Row{}, "New")
	if err != nil || result.Exit || result.Selected != "wcc" {
		t.Fatal(result, err)
	}
	if !has(h.events, `"cwd":"/project with spaces"`) || !has(h.events, `"focus":false`) || has(h.events, `workspace.focus {"workspace_id":"wcc"}`) {
		t.Fatal(h.events)
	}
	if err := h.s.Cycle(1); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "select-workspace 2 -s source") {
		t.Fatal("respect explicit order, loop, skip unnamed empty")
	}
}
func TestWorkspaceCreationPassesNameToLauncher(t *testing.T) {
	h := fixture(t)
	h.s.Trial = "/checkout with spaces/bin/tuios-trial"
	want := []string{"new-workspace", "review notes", "--no-focus"}
	h.s.run = func(_ context.Context, name string, args ...string) ([]byte, error) {
		if name != h.s.Trial || !reflect.DeepEqual(args, want) {
			t.Fatalf("%q %q", name, args)
		}
		return []byte("3\n"), nil
	}
	exit, err := h.s.Act("create-workspace", Row{}, "review notes")
	if err != nil || exit.Exit || exit.Selected != "3" {
		t.Fatalf("%v %v", exit, err)
	}
}

func TestClosePopupNeverClosesOrdinaryShell(t *testing.T) {
	h := fixture(t)
	t.Setenv("TUIOS_PICKER_POPUP", "")
	h.s.ClosePopup()
	if has(h.events, "pane.close") {
		t.Fatal("manual picker closes user shell")
	}
	t.Setenv("TUIOS_PICKER_POPUP", "1")
	h.s.ClosePopup()
	if !has(h.events, `pane.close {"pane_id":"popup"}`) {
		t.Fatal(h.events)
	}
}
func TestUnixRPCFramingAndErrors(t *testing.T) {
	for _, fail := range []bool{false, true} {
		t.Run(fmt.Sprint(fail), func(t *testing.T) {
			// macOS limits Unix socket paths to 104 bytes, shorter than t.TempDir.
			dir, err := os.MkdirTemp("/tmp", "picker-rpc-")
			if err != nil {
				t.Fatal(err)
			}
			defer os.RemoveAll(dir)
			s := New()
			s.Socket = filepath.Join(dir, "sock")
			listener, err := net.Listen("unix", s.Socket+".herdr")
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			seen := make(chan string, 1)
			go func() {
				c, e := listener.Accept()
				if e != nil {
					seen <- e.Error()
					return
				}
				defer c.Close()
				line, e := bufio.NewReader(c).ReadString('\n')
				if e != nil {
					seen <- e.Error()
					return
				}
				seen <- line
				if fail {
					fmt.Fprintln(c, `{"error":{"message":"missing target"}}`)
				} else {
					fmt.Fprintln(c, `{"result":{"value":42}}`)
				}
			}()
			var result struct{ Value int }
			err = s.rpc("test", nil, &result)
			if fail {
				if err == nil || err.Error() != "missing target" {
					t.Fatal(err)
				}
			} else if err != nil || result.Value != 42 {
				t.Fatal(result, err)
			}
			request := <-seen
			if !strings.Contains(request, `"params":{}`) || !strings.HasSuffix(request, "\n") {
				t.Fatal(request)
			}
		})
	}
}
