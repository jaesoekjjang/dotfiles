package tuios

import (
	"strings"
	"testing"
)

func TestAgentAggregationDoesNotHideDoneOrCountIdleAndPopup(t *testing.T) {
	h := fixture(t)
	h.panes = `{"windows":[{"window_id":"popup","workspace":1,"agent_state":"done"},{"window_id":"a","workspace":1,"agent_state":"done"},{"window_id":"b","workspace":1,"agent_state":"working"},{"window_id":"c","workspace":2,"agent_state":"idle"},{"window_id":"d","workspace":2,"agent_state":"needs_input"}]}`
	for _, mode := range []string{"sessions", "workspaces"} {
		data, err := h.s.Snapshot(mode)
		if err != nil {
			t.Fatal(err)
		}
		for _, row := range data.Rows {
			if row.Session != "source" {
				continue
			}
			if row.Kind == "workspace" && row.Number == 1 && (row.Agents.Done != 1 || row.Agents.Working != 1) {
				t.Fatal(row)
			}
			if row.Kind == "workspace" && row.Number == 2 && (row.Agents.Done != 0 || row.Agents.NeedsInput != 1) {
				t.Fatal(row)
			}
			if row.Kind == "session" && (row.Agents.Done != 1 || row.Agents.Working != 1 || row.Agents.NeedsInput != 1) {
				t.Fatal(row)
			}
		}
	}
}
func TestMovePinsSourceAndOffersNewFirst(t *testing.T) {
	h := fixture(t)
	t.Setenv("TUIOS_ACTIVE_PANE_ID", "editor")
	if err := h.s.PinMoveSource(); err != nil {
		t.Fatal(err)
	}
	data, err := h.s.Snapshot("move-pane")
	if err != nil {
		t.Fatal(err)
	}
	if len(data.Rows) != 2 || data.Rows[0].ID != "move:new" || data.Rows[1].Number != 2 {
		t.Fatal(data)
	}
	for _, dest := range data.Rows {
		h.events = nil
		result, err := h.s.Act("move", dest, "")
		if err != nil || !result.Exit {
			t.Fatal(result, err)
		}
		number := "2"
		if dest.Kind == "new-workspace" {
			number = "3"
		}
		if !has(h.events, "move-window "+number+" -s source -w editor --follow") {
			t.Fatal(h.events)
		}
	}
}
func TestMoveRejectsLostSourceDestinationAndPopup(t *testing.T) {
	for _, scenario := range []string{"missing", "moved", "popup", "session", "destination", "same", "full"} {
		t.Run(scenario, func(t *testing.T) {
			h := fixture(t)
			t.Setenv("TUIOS_ACTIVE_PANE_ID", "editor")
			if err := h.s.PinMoveSource(); err != nil {
				t.Fatal(err)
			}
			dest := Row{Kind: "workspace", Number: 2, Session: "source"}
			switch scenario {
			case "missing":
				h.panes = `{"windows":[]}`
			case "moved":
				h.panes = `{"windows":[{"window_id":"editor","workspace":2}]}`
			case "popup":
				h.s.MoveSource.ID = "popup"
			case "session":
				h.s.MoveSource.SessionID = "replaced"
			case "destination":
				dest.Number = 8
			case "same":
				dest.Number = 1
			case "full":
				dest.Kind = "new-workspace"
				dest.ID = "move:new"
				h.tabs["source"] = `{"workspaces":[{"workspace":1,"window_count":1,"current":true},{"workspace":2,"window_count":1}]}`
			}
			if _, err := h.s.Act("move", dest, ""); err == nil {
				t.Fatal("invalid move accepted")
			}
			for _, event := range h.events {
				if strings.Contains(event, "move-window") {
					t.Fatal(event)
				}
			}
		})
	}
	h := fixture(t)
	t.Setenv("TUIOS_ACTIVE_PANE_ID", "popup")
	if h.s.PinMoveSource() == nil {
		t.Fatal("popup cannot be source")
	}
}
