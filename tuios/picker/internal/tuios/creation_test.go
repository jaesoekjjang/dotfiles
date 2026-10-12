package tuios

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCreationFolderUsesSelectedPaneOrWorkspaceHistory(t *testing.T) {
	h := fixture(t)
	for _, tc := range []struct {
		row  Row
		want string
	}{
		{Row{ID: "waa", Kind: "session", Session: "source"}, "/tmp/project"},
		{Row{ID: "1", Kind: "workspace", Session: "source", Number: 1}, "/tmp/project"},
		{Row{ID: "pane:1:editor", Kind: "pane", Session: "source", Number: 1}, "/tmp/project"},
		{Row{ID: "2", Kind: "workspace", Session: "source", Number: 2}, ""},
	} {
		folder, err := h.s.CreationFolder(tc.row)
		want := tc.want
		if want == "" {
			// No cwd in logs: do not borrow the editor in workspace 1.
			home, _ := os.UserHomeDir()
			want = home
		}
		if err != nil || folder.Path != want || folder.Source == "" {
			t.Fatal(tc.row, folder, err)
		}
	}
	if has(h.events, "new-window") || has(h.events, "workspace.create") {
		t.Fatal("suggesting a folder must be read-only")
	}
}

func TestResolveCreationFolderAndValidateBeforeMutation(t *testing.T) {
	base := t.TempDir()
	dir := filepath.Join(base, "한글 folder $(literal)")
	if err := os.Mkdir(dir, 0700); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(base, "file")
	if err := os.WriteFile(file, []byte("test"), 0600); err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{dir, filepath.Base(dir)} {
		got, err := ResolveCreationFolder(value, base)
		if err != nil || got != dir {
			t.Fatal(got, err)
		}
	}
	home, _ := os.UserHomeDir()
	if got, err := ResolveCreationFolder("~/", ""); err != nil || got != home {
		t.Fatal(got, err)
	}
	for _, invalid := range []string{"", file, filepath.Join(base, "missing"), "relative", "a\nb"} {
		h := fixture(t)
		if _, err := h.s.Create("create-session", Row{}, "new", invalid); err == nil || len(h.events) != 0 {
			t.Fatal("invalid folder caused creation", invalid, h.events)
		}
	}
	// The chosen folder wins even after the source pane changes directory.
	h := fixture(t)
	h.panes = `{"windows":[{"window_id":"editor","workspace":1,"cwd":"/changed"}]}`
	if _, err := h.s.Create("create-workspace", Row{}, "new", dir); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "--cwd "+dir+" --no-focus") || has(h.events, "--cwd /changed") {
		t.Fatal(h.events)
	}
}

func destinationSlots() string {
	return `{"workspaces":[{"workspace":1,"name":"other","window_count":1,"current":true},{"workspace":2,"name":"","window_count":0},{"workspace":3,"name":"","window_count":0}]}`
}

func TestCreateWorkspaceInOtherSessionWithExplicitFolderAndReportPartialSuccess(t *testing.T) {
	for _, renameFails := range []bool{false, true} {
		t.Run(fmt.Sprint(renameFails), func(t *testing.T) {
			h := fixture(t)
			folder := t.TempDir()
			h.tabs["destination"] = destinationSlots()
			h.panes = `{"windows":[{"window_id":"remote","workspace":1,"cwd":"/destination with spaces"}]}`
			run := h.s.run
			h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
				if renameFails && args[0] == "set-workspace-name" {
					return nil, fmt.Errorf("rename failed")
				}
				return run(ctx, name, args...)
			}
			result, err := h.s.Create("create-workspace", Row{ID: "wbb", Kind: "session", Session: "destination", SessionID: "wbb"}, "review notes", folder)
			if err != nil || result.Selected != "ws:wbb:2" || result.Exit || (result.Warning != "") != renameFails {
				t.Fatal(result, err)
			}
			if !has(h.events, "new-window -s destination shell --workspace 2 --cwd "+folder+" --no-focus") {
				t.Fatal("must target selected session and its cwd", h.events)
			}
			if has(h.events, "select-workspace") || has(h.events, "workspace.focus") || has(h.events, "new-window -s source") {
				t.Fatal("creation must not switch or target launch session", h.events)
			}
		})
	}
}

func TestCreatePaneUsesExplicitFolderAndReturnsSelection(t *testing.T) {
	h := fixture(t)
	folder := t.TempDir()
	h.s.Trial = "/checkout with spaces/bin/tuios-trial"
	h.panes = `{"windows":[{"window_id":"popup","workspace":2,"cwd":"/wrong popup","focused":true},{"window_id":"editor","workspace":1,"cwd":"/other"},{"window_id":"log","workspace":2,"cwd":"/logs with spaces"}]}`
	run := h.s.run
	h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		out, err := run(ctx, name, args...)
		if args[0] == "new-window" {
			return []byte("new-pane-id\n"), nil
		}
		return out, err
	}
	result, err := h.s.Create("create-pane", Row{ID: "2", Kind: "workspace", Session: "source", Number: 2}, "server logs", folder)
	if err != nil || result.Selected != "pane:2:new-pane-id" {
		t.Fatal(result, err)
	}
	if !has(h.events, "new-window -s source server logs --workspace 2 --cwd "+folder+" --no-focus --print-id -- /checkout with spaces/bin/tuios-trial app /bin/zsh") {
		t.Fatal(h.events)
	}
}

func TestCreationRejectsMissingOrReplacedParentBeforeMutation(t *testing.T) {
	for _, row := range []Row{
		{ID: "3", Kind: "workspace", Session: "source", Number: 3}, // Empty inactive slot is not a workspace.
		{ID: "old", Kind: "session", Session: "destination", SessionID: "old"},
		{ID: "missing", Kind: "session"},
	} {
		h := fixture(t)
		folder := t.TempDir()
		action := "create-workspace"
		if row.Kind == "workspace" {
			action = "create-pane"
		}
		if _, err := h.s.Create(action, row, "new", folder); err == nil || has(h.events, "new-window") {
			t.Fatal("closed or replaced target must not cause fallback creation", row, h.events)
		}
	}
}

func TestWorkspaceSlotPolicyAppendReuseAndFull(t *testing.T) {
	for _, tc := range []struct {
		name string
		last int
		hole int
		want int
	}{
		{"append after named slot", 4, 2, 5},
		{"reuse hole when tail is full", 9, 2, 2},
		{"full", 9, 0, 0},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tabs := workspaceList{}
			for n := 9; n >= 1; n-- { // Input order must not influence slot allocation.
				tab := workspace{Number: n}
				if n <= tc.last && n != tc.hole {
					tab.Name = "reserved"
				}
				if n == 1 {
					tab.Current = true
				}
				tabs.Items = append(tabs.Items, tab)
			}
			n, err := nextWorkspaceSlot(tabs)
			if n != tc.want || (err != nil) != (tc.want == 0) {
				t.Fatal(n, err)
			}
		})
	}
}

func TestFullWorkspaceAndSpawnFailureDoNotRename(t *testing.T) {
	h := fixture(t)
	folder := t.TempDir()
	var tabs []string
	for n := 1; n <= 9; n++ {
		tabs = append(tabs, fmt.Sprintf(`{"workspace":%d,"window_count":1}`, n))
	}
	h.tabs["source"] = `{"workspaces":[` + strings.Join(tabs, ",") + `]}`
	if _, err := h.s.Create("create-workspace", Row{}, "new", folder); err == nil || has(h.events, "new-window") {
		t.Fatal("full workspace must fail without mutation", h.events)
	}
	h = fixture(t)
	run := h.s.run
	h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if args[0] == "new-window" {
			return nil, fmt.Errorf("spawn failed")
		}
		return run(ctx, name, args...)
	}
	if _, err := h.s.Create("create-workspace", Row{}, "new", folder); err == nil || has(h.events, "set-workspace-name") {
		t.Fatal("spawn failure must not leave a name-only slot", h.events)
	}
}
