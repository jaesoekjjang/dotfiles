package tuios

import (
	"fmt"
	"strings"
)

// The composer pins the previewed pane. Never fall back to the focused pane:
// focus can change while the user is writing, and may be the picker itself.
func (s *Service) sendInput(row Row, text string) error {
	parts := strings.SplitN(row.ID, ":", 3)
	if row.Kind != "pane" || len(parts) != 3 || parts[2] == "" || parts[2] == s.Popup || row.Session == "" {
		return fmt.Errorf("입력을 보낼 pane이 없습니다")
	}
	if strings.TrimSpace(text) == "" {
		return fmt.Errorf("보낼 내용을 입력하세요")
	}
	if strings.ContainsAny(text, "\r\n\x00\x1b") {
		return fmt.Errorf("한 줄의 텍스트만 보낼 수 있습니다")
	}
	var panes paneList
	if err := s.command(&panes, "list-windows", "-s", row.Session); err != nil {
		return err
	}
	for _, pane := range panes.Items {
		if pane.ID == parts[2] && pane.Number == row.Number {
			// Let TUIOS paste, wait for the application to take the text in,
			// then submit. Codex treats Enter inside a typing burst as a
			// pasted newline. Never retry an uncertain submission.
			return s.submit("send-text", map[string]any{
				"session": row.Session, "window": pane.ID, "text": text, "submit": true,
			}, nil)
		}
	}
	return fmt.Errorf("대상 pane이 종료되거나 다른 workspace로 이동했습니다")
}
