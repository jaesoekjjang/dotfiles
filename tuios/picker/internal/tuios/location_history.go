package tuios

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
)

type location struct {
	Session   string `json:"session"`
	Workspace int    `json:"workspace"`
}

// Track workspace locations per client, without recording pane focus changes.
func (s *Service) locationHistory(back bool) error {
	if err := os.MkdirAll(s.State, 0700); err != nil {
		return err
	}
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(s.Socket)))[:16]
	path := filepath.Join(s.State, "location-history-"+hash+".json")
	lock, err := os.OpenFile(path+".lock", os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	locked := true
	defer func() {
		if locked {
			syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
		}
	}()
	var sessions []session
	if err = s.command(&sessions, "ls"); err != nil {
		return err
	}
	var clients []client
	if err = s.command(&clients, "list-clients"); err != nil {
		return err
	}
	byName, byID := map[string]session{}, map[string]session{}
	for _, item := range sessions {
		byName[item.Name] = item
		byID[item.ID] = item
	}
	old := map[string][]location{}
	data, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if len(data) > 0 {
		if err = json.Unmarshal(data, &old); err != nil {
			return err
		}
	}
	tabs := map[string]workspaceList{}
	readTabs := func(name string) (workspaceList, error) {
		if v, ok := tabs[name]; ok {
			return v, nil
		}
		var v workspaceList
		err := s.command(&v, "list-workspaces", "-s", name)
		if err == nil {
			tabs[name] = v
		}
		return v, err
	}
	live := map[string][]location{}
	var matches []client
	for _, c := range clients {
		item, ok := byName[c.Session]
		if !ok || c.PID == 0 {
			continue
		}
		ws, err := readTabs(c.Session)
		if err != nil {
			return err
		}
		var current location
		for _, w := range ws.Items {
			if w.Current {
				current = location{item.ID, w.Number}
				break
			}
		}
		if current.Workspace == 0 {
			continue
		}
		key := strconv.Itoa(c.PID)
		recent := []location{current}
		for _, visit := range old[key] {
			if visit != current && byID[visit.Session].Name != "" && len(recent) < 40 {
				recent = append(recent, visit)
			}
		}
		live[key] = recent
		if c.Session == s.Target {
			matches = append(matches, c)
		}
	}
	data, err = json.Marshal(live)
	if err != nil {
		return err
	}
	if err = os.WriteFile(path+".tmp", data, 0600); err != nil {
		return err
	}
	if err = os.Rename(path+".tmp", path); err != nil {
		return err
	}
	var destination location
	var selected client
	if back {
		if len(matches) != 1 {
			return fmt.Errorf("직전 위치 복귀에는 현재 session에 연결된 창이 하나여야 합니다")
		}
		selected = matches[0]
		for _, visit := range live[strconv.Itoa(selected.PID)][1:] {
			item := byID[visit.Session]
			ws, err := readTabs(item.Name)
			if err != nil {
				return err
			}
			for _, w := range ws.Items {
				if w.Number == visit.Workspace && w.Count > 0 {
					destination = visit
					break
				}
			}
			if destination.Session != "" {
				break
			}
		}
	}
	// Switching can run hooks which need this same lock.
	syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	locked = false
	if destination.Session == "" {
		return nil
	}
	name := byID[destination.Session].Name
	if err = s.command(nil, "select-workspace", strconv.Itoa(destination.Workspace), "-s", name); err != nil {
		return err
	}
	if name != s.Target {
		if err = s.command(nil, "switch-session", name, "--client", selected.ID); err != nil {
			return err
		}
	}
	return s.RecordLocation()
}

func (s *Service) RecordLocation() error { return s.locationHistory(false) }
func (s *Service) LastLocation() error   { return s.locationHistory(true) }
