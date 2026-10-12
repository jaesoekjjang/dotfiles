package tuios

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

func destinationSlots() string {
	return `{"workspaces":[{"workspace":1,"name":"other","window_count":1,"current":true},{"workspace":2,"name":"","window_count":0},{"workspace":3,"name":"","window_count":0}]}`
}

func TestCreateWorkspaceInOtherSessionAndReportPartialSuccess(t *testing.T) {
	for _, renameFails := range []bool{false, true} {
		t.Run(fmt.Sprint(renameFails), func(t *testing.T) {
			h := fixture(t)
			h.tabs["destination"] = destinationSlots()
			h.panes = `{"windows":[{"window_id":"remote","workspace":1,"cwd":"/destination with spaces"}]}`
			run := h.s.run
			h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
				if renameFails && args[0] == "set-workspace-name" {
					return nil, fmt.Errorf("rename failed")
				}
				return run(ctx, name, args...)
			}
			result, err := h.s.Act("create-workspace", Row{ID: "wbb", Kind: "session", Session: "destination", SessionID: "wbb"}, "review notes")
			if err != nil || result.Selected != "ws:wbb:2" || result.Exit || (result.Warning != "") != renameFails {
				t.Fatal(result, err)
			}
			if !has(h.events, "new-window -s destination shell --workspace 2 --cwd /destination with spaces --no-focus") {
				t.Fatal("must target selected session and its cwd", h.events)
			}
			if has(h.events, "select-workspace") || has(h.events, "workspace.focus") || has(h.events, "new-window -s source") {
				t.Fatal("creation must not switch or target launch session", h.events)
			}
		})
	}
}

func TestCreatePaneUsesParentWorkspaceCwdAndReturnsSelection(t *testing.T) {
	h := fixture(t)
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
	result, err := h.s.Act("create-pane", Row{ID: "2", Kind: "workspace", Session: "source", Number: 2}, "server logs")
	if err != nil || result.Selected != "pane:2:new-pane-id" {
		t.Fatal(result, err)
	}
	if !has(h.events, "new-window -s source server logs --workspace 2 --cwd /logs with spaces --no-focus --print-id -- /checkout with spaces/bin/tuios-trial app /bin/zsh") {
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
		action := "create-workspace"
		if row.Kind == "workspace" {
			action = "create-pane"
		}
		if _, err := h.s.Act(action, row, "new"); err == nil || has(h.events, "new-window") {
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
	var tabs []string
	for n := 1; n <= 9; n++ {
		tabs = append(tabs, fmt.Sprintf(`{"workspace":%d,"window_count":1}`, n))
	}
	h.tabs["source"] = `{"workspaces":[` + strings.Join(tabs, ",") + `]}`
	if _, err := h.s.Act("create-workspace", Row{}, "new"); err == nil || has(h.events, "new-window") {
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
	if _, err := h.s.Act("create-workspace", Row{}, "new"); err == nil || has(h.events, "set-workspace-name") {
		t.Fatal("spawn failure must not leave a name-only slot", h.events)
	}
}
