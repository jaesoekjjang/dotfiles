package tuios

import (
	"fmt"
	"reflect"
	"strings"
	"testing"
)

func TestSessionNavigationMovesSourceClientWithDestinationAlreadyAttached(t *testing.T) {
	h := fixture(t)
	h.clients = `[{"client_id":"other-window","pid":20,"session":"destination"},{"client_id":"c1","pid":10,"session":"source"}]`
	result, err := h.s.Act("enter", Row{Kind: "session", Session: "destination", SessionID: "wbb"}, "")
	if err != nil || !result.Exit {
		t.Fatalf("%+v %v", result, err)
	}
	want := []string{"tuios list-clients --json", "tuios switch-session destination --client c1 --json"}
	if !reflect.DeepEqual(h.events, want) {
		t.Fatalf("wrong client or target: %v", h.events)
	}
}

func TestSessionNavigationDoesNotSwitchCurrentSession(t *testing.T) {
	h := fixture(t)
	result, err := h.s.Act("enter", Row{Kind: "session", Session: "source", SessionID: "waa"}, "")
	if err != nil || !result.Exit || len(h.events) != 0 {
		t.Fatalf("%+v %v %v", result, err, h.events)
	}
}

func TestSessionNavigationRefusesMissingOrAmbiguousSourceClients(t *testing.T) {
	for _, clients := range []string{
		`[{"client_id":"other-window","session":"destination"}]`,
		`[{"client_id":"c1","session":"source"},{"client_id":"c2","session":"source"}]`,
	} {
		h := fixture(t)
		h.clients = clients
		_, err := h.s.Act("enter", Row{Kind: "session", Session: "destination"}, "")
		if err == nil || !strings.Contains(err.Error(), "현재 세션에 연결된 창") || has(h.events, "switch-session") || has(h.events, "workspace.focus") {
			t.Fatalf("must refuse guessing a client: %v %v", err, h.events)
		}
	}
}

func TestCycleSkipsEmptyWorkspacesAndWraps(t *testing.T) {
	for _, tc := range []struct {
		name    string
		current int
		step    int
		order   string
		want    int
	}{
		{"next wraps", 2, 1, "null", 1},
		{"previous wraps", 1, -1, "null", 2},
		{"next from empty", 3, 1, "null", 1},
		{"previous from empty", 3, -1, "null", 2},
		{"custom order next", 1, 1, "[2,3,1]", 2},
		{"custom order previous", 2, -1, "[2,3,1]", 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			h := fixture(t)
			h.tabs["source"] = fmt.Sprintf(`{"order":%s,"workspaces":[
				{"workspace":1,"window_count":1,"current":%t},
				{"workspace":2,"window_count":1,"current":%t},
				{"workspace":3,"name":"closed review","window_count":0,"current":%t},
				{"workspace":4,"window_count":0}]}`, tc.order, tc.current == 1, tc.current == 2, tc.current == 3)
			if err := h.s.Cycle(tc.step); err != nil {
				t.Fatal(err)
			}
			if len(h.events) != 2 || !has(h.events, fmt.Sprintf("select-workspace %d -s source", tc.want)) {
				t.Fatal(h.events)
			}
		})
	}
}

func TestCycleSingleWorkspaceDoesNotSelectEmptySlot(t *testing.T) {
	for _, step := range []int{-1, 1} {
		h := fixture(t)
		h.tabs["source"] = `{"workspaces":[{"workspace":1,"window_count":1,"current":true},{"workspace":2,"name":"closed review","window_count":0}]}`
		if err := h.s.Cycle(step); err != nil {
			t.Fatal(err)
		}
		if len(h.events) != 1 {
			t.Fatal(h.events)
		}
	}
}
