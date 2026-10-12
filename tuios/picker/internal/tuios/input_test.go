package tuios

import (
	"reflect"
	"testing"
)

func TestSendInputLiteralPinnedPaneWithEnter(t *testing.T) {
	h := fixture(t)
	row := Row{ID: "pane:waa:editor", Kind: "pane", Session: "source", Number: 1}
	var writes []any
	h.s.submit = func(verb string, params, result any) error {
		if verb != "send-text" {
			t.Fatalf("unexpected verb: %s", verb)
		}
		writes = append(writes, params)
		return nil
	}
	text := "  한글 '$(echo literal)' --help  "
	if _, err := h.s.Act("send", row, text); err != nil {
		t.Fatal(err)
	}
	want := []any{map[string]any{"session": "source", "window": "editor", "text": text, "submit": true}}
	if !reflect.DeepEqual(writes, want) {
		t.Fatalf("writes = %#v", writes)
	}
	for _, tc := range []struct {
		name string
		row  Row
		text string
	}{
		{"closed", Row{ID: "pane:waa:gone", Kind: "pane", Session: "source", Number: 1}, text},
		{"moved", Row{ID: row.ID, Kind: "pane", Session: "source", Number: 2}, text},
		{"popup", Row{ID: "pane:waa:popup", Kind: "pane", Session: "source", Number: 1}, text},
		{"malformed", Row{ID: "editor", Kind: "pane", Session: "source"}, text},
		{"empty", row, "  "},
		{"multiline", row, "one\ntwo"},
		{"escape", row, "\x1b[A"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := h.s.Act("send", tc.row, tc.text); err == nil {
				t.Fatal("invalid target or input accepted")
			}
			if len(writes) != 1 {
				t.Fatal("invalid send wrote to a terminal")
			}
		})
	}
}
