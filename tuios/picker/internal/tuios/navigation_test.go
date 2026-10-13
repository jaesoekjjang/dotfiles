package tuios

import (
	"fmt"
	"testing"
)

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
