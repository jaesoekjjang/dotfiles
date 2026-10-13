package tuios

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

func TestWorkspacePreviewCapturesSplitWithoutMutations(t *testing.T) {
	h := fixture(t)
	h.panes = `{"windows":[{"window_id":"popup","workspace":1},{"window_id":"editor","workspace":1,"custom_name":"Editor","x":0,"y":0,"width":60,"height":40},{"window_id":"right","workspace":1,"custom_name":"Server","x":60,"y":0,"width":40,"height":40,"agent_state":"done"},{"window_id":"hidden","workspace":1,"minimized":true},{"window_id":"other","workspace":2}]}`
	for _, kind := range []string{"workspace"} {
		preview, err := h.s.Preview(Row{Kind: kind, Number: 1, Session: "source"})
		if err != nil || len(preview.Panes) != 2 || preview.PaneID != "editor" {
			t.Fatal(preview, err)
		}
		if preview.Panes[1].X != 60 || preview.Panes[1].AgentState != "done" {
			t.Fatal(preview.Panes)
		}
	}
	for _, event := range h.events {
		if strings.Contains(event, "capture-pane") && !strings.Contains(event, "-w editor") && !strings.Contains(event, "-w right") {
			t.Fatal(event)
		}
		if strings.Contains(event, "resize") || strings.Contains(event, "focus-window") {
			t.Fatal(event)
		}
	}
	preview, err := h.s.Preview(Row{ID: "pane:1:right", Kind: "pane", Number: 1, Session: "source"})
	if err != nil || len(preview.Panes) != 0 || preview.PaneID != "right" {
		t.Fatal(preview, err)
	}
	run := h.s.run
	h.s.run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
		if args[0] == "capture-pane" && strings.Contains(strings.Join(args, " "), "-w right") {
			return nil, fmt.Errorf("gone")
		}
		return run(ctx, name, args...)
	}
	preview, err = h.s.Preview(Row{Kind: "workspace", Number: 1, Session: "source"})
	if err != nil || !strings.Contains(preview.Panes[1].Screen, "불러오지") || !strings.Contains(preview.Panes[0].Screen, "actual screen") {
		t.Fatal(preview, err)
	}
}

func TestSessionOverviewShowsAllWorkspacesWithoutCapturing(t *testing.T) {
	h := fixture(t)
	p, err := h.s.Preview(Row{Kind: "session", Session: "source"})
	if err != nil || !p.Overview || p.PaneID != "" || len(p.Panes) != 0 {
		t.Fatal(p, err)
	}
	for _, want := range []string{"Editor", "Logs", "현재 workspace"} {
		if !strings.Contains(p.Screen, want) {
			t.Fatal(p.Screen)
		}
	}
	if strings.Contains(p.Screen, "picker") {
		t.Fatal("popup included")
	}
	for _, event := range h.events {
		if strings.Contains(event, "capture-pane") {
			t.Fatal("overview captured terminal screens")
		}
	}
}
