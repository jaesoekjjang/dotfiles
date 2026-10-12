package tuios

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestNativeReadCommandsUseSocketAndPreserveCLIResults(t *testing.T) {
	for _, tc := range []struct {
		args              []string
		verb, reply, want string
	}{
		{[]string{"ls"}, "list-sessions", `{"sessions":[{"id":"aa","name":"project"}]}`, `[{"id":"aa","name":"project"}]`},
		{[]string{"list-clients"}, "list-clients", `{"clients":[{"pid":42,"session":"project"}]}`, `[{"pid":42,"session":"project"}]`},
		{[]string{"session-info", "-s", "project"}, "session-info", `{"session_id":"aa"}`, `{"session_id":"aa"}`},
		{[]string{"list-workspaces", "-s", "project"}, "list-workspaces", `{"order":[2,1],"workspaces":[]}`, `{"order":[2,1],"workspaces":[]}`},
		{[]string{"list-windows", "-s", "project"}, "list-windows", `{"windows":[]}`, `{"windows":[]}`},
	} {
		t.Run(tc.verb, func(t *testing.T) {
			dir, err := os.MkdirTemp("/tmp", "picker-read-")
			if err != nil {
				t.Fatal(err)
			}
			defer os.RemoveAll(dir)
			s := New()
			defer s.Close()
			s.Socket = filepath.Join(dir, "sock")
			s.run = func(context.Context, string, ...string) ([]byte, error) {
				return nil, fmt.Errorf("unexpected CLI process")
			}
			listener, err := net.Listen("unix", s.Socket)
			if err != nil {
				t.Fatal(err)
			}
			defer listener.Close()
			seen := make(chan map[string]any, 1)
			go func() {
				c, err := listener.Accept()
				if err != nil {
					seen <- nil
					return
				}
				defer c.Close()
				var request map[string]any
				if json.NewDecoder(bufio.NewReader(c)).Decode(&request) != nil {
					seen <- nil
					return
				}
				seen <- request
				fmt.Fprintf(c, "{\"result\":%s}\n", tc.reply)
			}()
			var got, want any
			if err := s.command(&got, tc.args...); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal([]byte(tc.want), &want); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, want) {
				t.Fatal(got, want)
			}
			request := <-seen
			if request["verb"] != tc.verb || request["method"] != nil {
				t.Fatal(request)
			}
			if len(tc.args) > 1 && request["params"].(map[string]any)["session"] != "project" {
				t.Fatal(request)
			}
		})
	}
}

func TestNativeReadErrorIsNotRetriedAsCLIAndMutationsStayCLI(t *testing.T) {
	h := fixture(t)
	h.s.read = func(string, any, any) error { return fmt.Errorf("read denied") }
	if err := h.s.command(nil, "list-workspaces", "-s", "source"); err == nil || err.Error() != "read denied" {
		t.Fatal(err)
	}
	if len(h.events) != 0 {
		t.Fatal("must not retry denied reads", h.events)
	}
	if err := h.s.command(nil, "select-workspace", "2", "-s", "source"); err != nil {
		t.Fatal(err)
	}
	if !has(h.events, "tuios select-workspace 2 -s source --json") {
		t.Fatal(h.events)
	}
}

func TestPreviewUsesNativeTextCapture(t *testing.T) {
	h := fixture(t)
	run := h.s.run
	h.s.read = func(verb string, params, result any) error {
		if verb == "capture-pane" {
			p := params.(map[string]any)
			if p["session"] != "source" || p["window"] != "editor" || p["ansi"] != true {
				t.Fatal(p)
			}
			return json.Unmarshal([]byte(`{"content":"\u001b[31mtext screen\u001b[0m\n"}`), result)
		}
		out, err := run(h.s.ctx, "tuios", verb, "-s", params.(map[string]any)["session"].(string), "--json")
		if err != nil {
			return err
		}
		return json.Unmarshal(out, result)
	}
	h.s.run = func(context.Context, string, ...string) ([]byte, error) {
		return nil, fmt.Errorf("unexpected CLI capture")
	}
	preview, err := h.s.Preview(Row{Kind: "workspace", Number: 1, Session: "source"})
	if err != nil || !strings.Contains(preview.Screen, "\x1b[31mtext screen") || preview.Path != "/tmp/project" {
		t.Fatal(preview, err)
	}
}
