package tuios

import "encoding/json"

// These reads use the same JSON verbs as the installed TUIOS CLI. Avoid
// starting the CLI for every session or preview; no disk snapshot is reused.
// Other commands continue through their CLI path; the input composer uses
// native send-text with submit, which the CLI does not expose.
func (s *Service) readCommand(result any, args []string) (bool, error) {
	if s.read == nil || len(args) == 0 {
		return false, nil
	}
	if len(args) == 1 && (args[0] == "ls" || args[0] == "list-clients") {
		verb, key := "list-sessions", "sessions"
		if args[0] == "list-clients" {
			verb, key = "list-clients", "clients"
		}
		var envelope map[string]json.RawMessage
		if err := s.read(verb, nil, &envelope); err != nil {
			return true, err
		}
		if result == nil {
			return true, nil
		}
		return true, json.Unmarshal(envelope[key], result)
	}
	if len(args) == 3 && args[1] == "-s" {
		switch args[0] {
		case "session-info", "list-workspaces", "list-windows":
			return true, s.read(args[0], map[string]any{"session": args[2]}, result)
		}
	}
	return false, nil
}
