package main

import (
	"fmt"
	"os"
	"strings"

	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
)

func run(args []string) error {
	command := "sessions"
	if len(args) > 0 {
		command = args[0]
	}
	if command == "--help" || command == "help" || command == "-h" {
		fmt.Println("tuios-picker [sessions|workspaces|close-session|close-workspace|last-session|next-workspace|prev-workspace|record-session]\nGo / Bubble Tea · TUIOS 안에서 실행")
		return nil
	}
	s := tuios.New()
	defer s.Close()
	if command == "record-session" {
		return s.Record()
	}
	if command == "_close" {
		if len(args) != 5 {
			return fmt.Errorf("잘못된 종료 인자")
		}
		return s.FinishClose(args[1], args[2], args[3], args[4])
	}
	if s.Target == "" {
		return fmt.Errorf("TUIOS 안에서 실행하세요")
	}
	switch command {
	case "last-session":
		return s.Last()
	case "next-workspace":
		return s.Cycle(1)
	case "prev-workspace":
		return s.Cycle(-1)
	case "sessions", "workspaces", "close-session", "close-workspace":
		defer s.ClosePopup()
		mode := command
		if strings.HasPrefix(command, "close-") {
			mode = strings.TrimPrefix(command, "close-") + "s"
		}
		m := newModel(s, mode)
		if strings.HasPrefix(command, "close-") {
			row, err := s.Current(strings.TrimPrefix(command, "close-"))
			if err != nil {
				return err
			}
			m.standalone = true
			m.loading = false
			m.modal = "close"
			m.modalRow = row
			m.search.Blur()
			m.showPreview = false
		}
		if err := s.PreparePopup(); err != nil {
			return err
		}
		_, err := tea.NewProgram(m).Run()
		return err
	default:
		return fmt.Errorf("알 수 없는 picker: %s", command)
	}
}
func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "tuios-picker:", err)
		os.Exit(1)
	}
}
