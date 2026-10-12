package main

import (
	tea "charm.land/bubbletea/v2"
	"dotfiles/tuios-picker/internal/tuios"
	"time"
)

type agentTick struct{}
type agentRefresh struct {
	snapshot tuios.Snapshot
	err      error
}

func nextAgentTick() tea.Cmd {
	return tea.Tick(2*time.Second, func(time.Time) tea.Msg { return agentTick{} })
}
