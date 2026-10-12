package tuios

import (
	"fmt"
	"strings"
)

// Count states separately so busy panes cannot hide another pane's completion.
type AgentCounts struct{ Done, Working, NeedsInput, Errored int }

func (a *AgentCounts) add(b AgentCounts) {
	a.Done += b.Done
	a.Working += b.Working
	a.NeedsInput += b.NeedsInput
	a.Errored += b.Errored
}
func agentCounts(state string) AgentCounts {
	switch state {
	case "done":
		return AgentCounts{Done: 1}
	case "working":
		return AgentCounts{Working: 1}
	case "needs_input":
		return AgentCounts{NeedsInput: 1}
	case "errored":
		return AgentCounts{Errored: 1}
	}
	return AgentCounts{}
}
func (a AgentCounts) Label() string {
	var labels []string
	if a.Done > 0 {
		labels = append(labels, fmt.Sprintf("■ 완료 %d", a.Done))
	}
	if a.NeedsInput > 0 {
		labels = append(labels, fmt.Sprintf("◆ 입력 대기 %d", a.NeedsInput))
	}
	if a.Errored > 0 {
		labels = append(labels, fmt.Sprintf("! 오류 %d", a.Errored))
	}
	if a.Working > 0 {
		labels = append(labels, fmt.Sprintf("● 작업 중 %d", a.Working))
	}
	return strings.Join(labels, " · ")
}
func countsFor(panes paneList, workspace int, popup string) AgentCounts {
	var counts AgentCounts
	for _, p := range panes.Items {
		if p.Number == workspace && p.ID != popup {
			counts.add(agentCounts(p.AgentState))
		}
	}
	return counts
}
