package tuios

import (
	"context"
	"encoding/json"
	"strconv"
	"testing"
)

func locationFixture(t *testing.T) *harness {
	h := fixture(t)
	run := h.s.run
	h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		out, err := run(ctx, name, args...)
		if err == nil && name == "tuios" && args[0] == "select-workspace" {
			target := "source"
			for i, a := range args {
				if a == "-s" {
					target = args[i+1]
				}
			}
			var tabs workspaceList
			json.Unmarshal([]byte(h.tabs[target]), &tabs)
			for i := range tabs.Items {
				tabs.Items[i].Current = args[1] == strconv.Itoa(tabs.Items[i].Number)
			}
			data, _ := json.Marshal(tabs)
			h.tabs[target] = string(data)
		}
		return out, err
	}
	return h
}

func TestUnifiedLocationRoundTripAcrossWorkspacesAndSessions(t *testing.T) {
	h := locationFixture(t)
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	if err := h.s.Cycle(1); err != nil {
		t.Fatal(err)
	}
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	h.clients = `[{"client_id":"c1","pid":10,"session":"destination"}]`
	h.s.Target = "destination"
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	if err := h.s.command(nil, "select-workspace", "1", "-s", "source"); err != nil {
		t.Fatal(err)
	}
	if err := h.s.LastLocation(); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "select-workspace 2 -s source") || !has(h.events, "switch-session source --client c1") {
		t.Fatal(h.events)
	}
	h.s.Target = "source"
	h.events = nil
	if err := h.s.LastLocation(); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "switch-session destination --client c1") {
		t.Fatal(h.events)
	}
}
func TestUnifiedLocationSameWorkspaceAndPaneChangesDoNotReplacePrevious(t *testing.T) {
	h := locationFixture(t)
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	if err := h.s.Cycle(1); err != nil {
		t.Fatal(err)
	}
	for range 3 {
		if err := h.s.RecordLocation(); err != nil {
			t.Fatal(err)
		}
	}
	h.events = nil
	if err := h.s.LastLocation(); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "select-workspace 1 -s source") {
		t.Fatal(h.events)
	}
	h.events = nil
	if err := h.s.LastLocation(); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "select-workspace 2 -s source") {
		t.Fatal(h.events)
	}
}
func TestUnifiedLocationSkipsClosedAndEmptyTargets(t *testing.T) {
	h := locationFixture(t)
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	if err := h.s.Cycle(1); err != nil {
		t.Fatal(err)
	}
	if err := h.s.RecordLocation(); err != nil {
		t.Fatal(err)
	}
	h.tabs["source"] = `{"workspaces":[{"workspace":1,"window_count":0},{"workspace":2,"current":true,"window_count":1}]}`
	h.events = nil
	if err := h.s.LastLocation(); err != nil {
		t.Fatal(err)
	}
	if has(h.events, "select-workspace") {
		t.Fatal(h.events)
	}
}
