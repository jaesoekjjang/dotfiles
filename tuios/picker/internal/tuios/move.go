package tuios

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"
)

// Native popup commands export the pane that had focus before opening.
// Never fall back to the popup's ID or whichever pane now has focus.
func (s *Service) PinMoveSource() error {
	id := os.Getenv("TUIOS_ACTIVE_PANE_ID")
	if id == "" || id == s.Popup {
		return fmt.Errorf("이동할 원래 pane을 확인하지 못했습니다")
	}
	var panes paneList
	if err := s.command(&panes, "list-windows", "-s", s.Target); err != nil {
		return err
	}
	sessionID, err := s.sessionID(s.Target)
	if err != nil {
		return err
	}
	for _, p := range panes.Items {
		if p.ID == id {
			s.MoveSource = Row{ID: id, Kind: "pane", Label: first(p.Custom, p.Display, p.Title, "pane"), Session: s.Target, SessionID: sessionID, Number: p.Number}
			return nil
		}
	}
	return fmt.Errorf("이동할 pane이 종료되었습니다")
}
func (s *Service) moveSnapshot() (Snapshot, error) {
	if s.MoveSource.ID == "" {
		return Snapshot{}, fmt.Errorf("이동할 pane이 없습니다")
	}
	data, err := s.Snapshot("workspaces")
	if err != nil {
		return Snapshot{}, err
	}
	result := Snapshot{Current: "move:new", Rows: []Row{{ID: "move:new", Kind: "new-workspace", Label: "+ 새 workspace", Session: s.MoveSource.Session}}}
	for _, r := range data.Rows {
		if r.Kind == "workspace" && r.Number != s.MoveSource.Number {
			result.Rows = append(result.Rows, r)
		}
	}
	return result, nil
}
func (s *Service) movePane(destination Row, follow bool) (ActionResult, error) {
	source := s.MoveSource
	if source.ID == "" || source.ID == s.Popup || source.Session == "" || destination.Session != source.Session {
		return ActionResult{}, fmt.Errorf("이동 대상이 올바르지 않습니다")
	}
	currentID, err := s.sessionID(source.Session)
	if err != nil {
		return ActionResult{}, err
	}
	if source.SessionID != currentID {
		return ActionResult{}, fmt.Errorf("원래 session이 변경되거나 종료되었습니다")
	}
	var panes paneList
	if err = s.command(&panes, "list-windows", "-s", source.Session); err != nil {
		return ActionResult{}, err
	}
	found := false
	for _, p := range panes.Items {
		if p.ID == source.ID && p.Number == source.Number {
			found = true
		}
	}
	if !found {
		return ActionResult{}, fmt.Errorf("원래 pane이 종료되거나 다른 workspace로 이동했습니다")
	}
	var tabs workspaceList
	if err = s.command(&tabs, "list-workspaces", "-s", source.Session); err != nil {
		return ActionResult{}, err
	}
	number := destination.Number
	if destination.Kind == "new-workspace" && destination.ID == "move:new" {
		number, err = nextWorkspaceSlot(tabs)
		if err != nil {
			return ActionResult{}, err
		}
	} else if destination.Kind == "workspace" {
		found = false
		for _, tab := range tabs.Items {
			if tab.Number == number && visible(tab) {
				found = true
			}
		}
		if !found {
			return ActionResult{}, fmt.Errorf("선택한 workspace가 종료되었습니다")
		}
	} else {
		return ActionResult{}, fmt.Errorf("workspace를 선택하세요")
	}
	if number == source.Number {
		return ActionResult{}, fmt.Errorf("현재 workspace로는 이동할 수 없습니다")
	}
	ctx, cancel := context.WithTimeout(s.ctx, 20*time.Second)
	defer cancel()
	args := []string{"move-window", strconv.Itoa(number), "-s", source.Session, "-w", source.ID}
	if follow {
		args = append(args, "--follow")
	}
	_, err = s.run(ctx, "tuios", args...)
	return ActionResult{Exit: err == nil}, err
}
