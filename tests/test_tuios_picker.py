import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
import tempfile
import subprocess
import io
from contextlib import redirect_stdout
from unittest.mock import patch


loader = importlib.machinery.SourceFileLoader("tuios_picker", str(Path(__file__).resolve().parents[1] / "bin/tuios-picker"))
spec = importlib.util.spec_from_loader(loader.name, loader)
picker = importlib.util.module_from_spec(spec)
loader.exec_module(picker)


class PickerTests(unittest.TestCase):
    def test_shared_help_uses_whole_width_and_falls_back_when_narrow(self):
        wide = picker.help_layout("workspace", 220)
        self.assertIn("--border-label-pos=2:bottom", wide)
        self.assertIn("--no-footer", wide)
        label = wide[wide.index("--border-label") + 1]
        self.assertNotIn("\n", label)
        for key in ("Enter", "Tab", "C-a", "C-r", "C-x", "C-/", "Esc"):
            self.assertIn(key, label)
        narrow = picker.help_layout("workspace", 60)
        self.assertIn("--footer", narrow)
        self.assertIn("\n", narrow[narrow.index("--footer") + 1])

    def test_workspace_jump_skips_panes_and_respects_search(self):
        import json
        rows = [("1", "1", "dev"), ("pane:1:a", "  └", "editor"),
                ("2", "2", "other"), ("pane:2:b", "  └", "shell"), ("3", "3", "dev")]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tree.json"
            path.write_text(json.dumps({"rows": rows}))
            for selected, query, step, expected in [
                ("1", "", "1", "pos(3)"), ("pane:2:b", "", "-1", "pos(1)"),
                ("pane:2:b", "", "1", "pos(5)"), ("1", "dev", "1", "pos(2)"),
                ("1", "", "-1", "pos(5)"), ("3", "", "1", "pos(1)"),
                ("3", "dev", "1", "pos(1)"), ("1", "dev", "-1", "pos(2)"),
                ("2", "other", "1", "pos(1)"), ("missing", "", "1", "")]:
                output = io.StringIO()
                with redirect_stdout(output):
                    picker.jump_workspace(str(path), selected, query, step)
                self.assertEqual(output.getvalue().strip(), expected)

    def test_session_expansion_children_search_and_group_jump(self):
        import json
        def cli(*args):
            if args[0] == "ls": return [{"id": "aa", "name": "real-name"}]
            return {"order": [2, 1, 3], "workspaces": [
                {"workspace": 1, "name": "dev", "window_count": 1, "current": True},
                {"workspace": 2, "name": "logs", "window_count": 0},
                {"workspace": 3, "name": "", "window_count": 0}]}
        items = [{"workspace_id": "waa", "label": "Project", "pane_count": 1},
                 {"workspace_id": "wbb", "label": "Other", "pane_count": 1}]
        with patch.object(picker, "cli", side_effect=cli):
            rows = picker.session_rows(items, "waa", {"waa"})
        self.assertEqual([r[0] for r in rows], ["waa", "ws:waa:2", "ws:waa:1", "wbb"])
        self.assertEqual(picker.filtered_rows(rows, "session", "logs")[0].split("\t")[0], "ws:waa:2")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tree.json"
            path.write_text(json.dumps({"kind": "session", "rows": rows, "expanded": ["waa"], "current": "waa"}))
            with redirect_stdout(io.StringIO()) as output:
                picker.jump_workspace(str(path), "ws:waa:1", "", "1")
            self.assertEqual(output.getvalue().strip(), "pos(4)")
            with patch.object(picker, "rpc", return_value={"workspaces": items}), redirect_stdout(io.StringIO()):
                picker.toggle_tree("real-name", str(path), "ws:waa:1")
            updated = json.loads(path.read_text())
            self.assertEqual(updated["expanded"], [])
            self.assertEqual(updated["kind"], "session")

    def test_session_child_enter_selects_workspace_before_switch(self):
        events = []
        items = [{"workspace_id": "waa", "pane_count": 1}]
        def rpc(method, **params):
            events.append((method, params))
            if method == "workspace.list": return {"workspaces": items}
            if method == "workspace.get": return {"workspace": items[0]}
        def cli(*args):
            events.append(args)
            return {"session_id": "aa"}
        for key in ("", "ctrl-r"):
            events.clear()
            with patch.dict(picker.os.environ, {"TUIOS_SESSION": "source"}), \
                 patch.object(picker.sys, "argv", ["picker", "sessions"]), \
                 patch.object(picker, "ordered_sessions", return_value=items), \
                 patch.object(picker, "cli", side_effect=cli), \
                 patch.object(picker, "rpc", side_effect=rpc), \
                 patch.object(picker, "session_name", return_value="destination"), \
                 patch.object(picker, "choose", return_value=(key, "ws:waa:2")):
                result = picker.main({"expanded": set()})
            if key == "":
                self.assertIsNone(result)
                self.assertEqual(events[-2:], [("select-workspace", "2", "-s", "destination"),
                                               ("workspace.focus", {"workspace_id": "waa"})])
            else:
                self.assertTrue(result)
                self.assertFalse(any(e[0] in ("workspace.focus", "workspace.close", "workspace.rename") for e in events))

    def test_session_child_delete_targets_workspace_and_preserves_session(self):
        items = [{"workspace_id": "waa", "pane_count": 1}]
        def cli(*args):
            if args[0] == "session-info": return {"session_id": "aa"}
            return {"workspaces": [{"workspace": 1, "current": True, "window_count": 1},
                                    {"workspace": 2, "name": "logs", "window_count": 1}]}
        def rpc(method, **kwargs):
            return {"workspaces": items} if method == "workspace.list" else {"workspace": items[0]}
        with patch.dict(picker.os.environ, {"TUIOS_SESSION": "source"}), \
             patch.object(picker.sys, "argv", ["picker", "sessions"]), \
             patch.object(picker, "ordered_sessions", return_value=items), \
             patch.object(picker, "cli", side_effect=cli), patch.object(picker, "rpc", side_effect=rpc), \
             patch.object(picker, "session_name", return_value="destination"), \
             patch.object(picker, "choose", return_value=("ctrl-x", "ws:waa:2")), \
             patch.object(picker, "confirm_close", return_value=True) as confirm, \
             patch.object(picker, "finish_close") as close:
            result = picker.main({"expanded": set()})
        self.assertTrue(result)
        confirm.assert_called_once_with("workspace", "logs", 1)
        close.assert_called_once_with("workspace", "2", "1", "destination")

    def test_toggle_all_expands_then_collapses_even_with_no_search_match(self):
        import json
        items = [{"workspace": 1, "current": True, "window_count": 1},
                 {"workspace": 2, "name": "logs", "window_count": 1}]
        panes = [{"workspace": 1, "window_id": "a"}, {"workspace": 2, "window_id": "b"}]
        def cli(*args):
            return {"workspaces": items} if args[0] == "list-workspaces" else {"windows": panes}
        with tempfile.TemporaryDirectory() as directory, patch.object(picker, "cli", side_effect=cli):
            path = Path(directory) / "tree.json"
            path.write_text(json.dumps({"kind": "workspace", "expanded": ["1"],
                                        "rows": picker.workspace_rows(items, panes, {"1"})}))
            with redirect_stdout(io.StringIO()):
                picker.toggle_tree("test", str(path), "pane:1:a", "", "all")
            self.assertEqual(set(json.loads(path.read_text())["expanded"]), {"1", "2"})
            with redirect_stdout(io.StringIO()):
                picker.toggle_tree("test", str(path), "", "no-match", "all")
            state = json.loads(path.read_text())
            self.assertEqual(state["expanded"], [])
            self.assertEqual([r[0] for r in state["rows"]], ["1", "2"])

    def test_styled_rows_preserve_search_and_stable_ids(self):
        rows = [("1", "▾ 1", "개발", "current"), ("pane:1:a", "  └", "editor", "nvim", "")]
        for query in ("개발", "editor", "1"):
            result = subprocess.run(["fzf", "--ansi", "--filter", query, "--delimiter", "\t",
                                     "--with-nth", "2..", "--nth", "1,2", "--tiebreak=index"],
                                    input=picker.render_rows(rows, styled=True), text=True, capture_output=True)
            self.assertEqual([line.split("\t")[0] for line in result.stdout.splitlines()],
                             [line.split("\t")[0] for line in picker.filtered_rows(rows, "workspace", query)])

    def test_render_keeps_unicode_columns_tree_indent_and_ids(self):
        rows = [("1", "▾ 1", "개발", "●", "1 pane"),
                ("pane:1:editor", "  └", "editor", "nvim", "")]
        rendered = picker.render_rows(rows).splitlines()
        fields = [line.split("\t") for line in rendered]
        self.assertEqual(fields[1][0], "pane:1:editor")
        self.assertTrue(fields[1][1].startswith("  └"))
        self.assertEqual(picker.cell_width(fields[0][2]), picker.cell_width(fields[1][2]))
        self.assertEqual(picker.filtered_rows(rows, "workspace", "개발")[0].split("\t")[0], "1")
        self.assertEqual(picker.filtered_rows(rows, "workspace", "editor")[0].split("\t")[0], "pane:1:editor")

    def test_query_and_selected_identity_survive_rename(self):
        rows = [("a", "project alpha"), ("b", "project beta renamed")]
        state = {"query": "project", "selected": "b", "position": 2}
        calls = []
        real_run = subprocess.run
        def run(args, **kwargs):
            if "--filter" in args:
                return real_run(args, **kwargs)
            calls.append(args)
            return subprocess.CompletedProcess(args, 0, "project\nctrl-r\nb\tproject beta renamed\n")
        with patch.object(picker.subprocess, "run", side_effect=run):
            result = picker.choose(rows, "session", "a", state, "session-a")
        self.assertEqual(result, ("ctrl-r", "b"))
        self.assertEqual(state, {"query": "project", "selected": "b", "position": 2, "expanded": set()})
        self.assertIn("start:pos(2)", calls[0])

    def test_deleted_selection_keeps_nearby_filtered_position(self):
        state = {"query": "", "selected": None, "position": 3}
        with patch.object(picker.subprocess, "run", return_value=subprocess.CompletedProcess([], 130, "")) as run:
            picker.choose([("a", "A"), ("b", "B")], "session", "a", state)
        self.assertIn("start:pos(2)", run.call_args.args[0])

    def test_recent_visits_win_over_daemon_activity(self):
        def cli(*args):
            if args[0] == "list-clients": return [{"pid": 7, "session": "current"}]
            return [{"id": "aa", "last_active": 1}, {"id": "bb", "last_active": 99}, {"id": "cc", "last_active": 50}]
        with patch.object(picker, "session_history", return_value={"7": ["aa", "cc"]}), \
             patch.object(picker, "cli", side_effect=cli):
            result = picker.ordered_sessions([{"workspace_id": "wbb"}, {"workspace_id": "wcc"}, {"workspace_id": "waa"}], "current")
        self.assertEqual([item["workspace_id"] for item in result], ["waa", "wcc", "wbb"])

    def test_preview_shows_ordered_structure_and_excludes_own_popup(self):
        def cli(*args):
            if args[0] == "list-workspaces":
                return {"order": [2, 1], "workspaces": [{"workspace": 1, "name": "dev"}, {"workspace": 2, "name": "shell"}]}
            return {"shell": "zsh", "windows": [
                {"workspace": 1, "window_id": "editor", "custom_name": "editor", "foreground_cmd": "nvim", "cwd": "/project"},
                {"workspace": 2, "window_id": "popup", "custom_name": "picker"}]}
        output = io.StringIO()
        with patch.object(picker, "cli", side_effect=cli), \
             patch.object(picker.subprocess, "check_output", return_value="actual screen\n"), \
             patch.dict(picker.os.environ, {"TUIOS_WINDOW_ID": "popup"}), redirect_stdout(output):
            picker.preview("workspace", "test", "1")
        self.assertIn("editor [nvim]", output.getvalue())
        self.assertNotIn("picker", output.getvalue())
        self.assertEqual([item["workspace"] for item in picker.workspace_order(cli("list-workspaces"))], [2, 1])

    def test_screen_preview_uses_workspace_focus_history_and_explicit_pane(self):
        def cli(*args):
            if args[0] == "ls": return [{"id": "aa", "name": "target"}]
            if args[0] == "list-workspaces":
                return {"workspaces": [{"workspace": 1, "current": True, "name": "dev", "focused_window_id": "popup",
                                         "focus_history": ["popup", "b", "a"]}]}
            return {"windows": [{"workspace": 1, "window_id": ident, "title": ident} for ident in ("popup", "a", "b")]}
        for kind, selected, expected in [("workspace", "1", "b"), ("workspace", "pane:1:a", "a"),
                                          ("session", "waa", "b"), ("session", "ws:waa:1", "b")]:
            with patch.object(picker, "cli", side_effect=cli), \
                 patch.dict(picker.os.environ, {"TUIOS_WINDOW_ID": "popup"}), \
                 patch.object(picker.subprocess, "check_output", return_value="\x1b[32mlive output\x1b[0m\n") as capture, \
                 redirect_stdout(io.StringIO()) as output:
                picker.preview(kind, "target", selected)
            self.assertEqual(capture.call_args.args[0], ["tuios", "capture-pane", "-s", "target", "-w", expected, "--ansi"])
            self.assertIn("\x1b[32mlive output\x1b[0m", output.getvalue())

    def test_closing_other_workspace_stays_in_picker(self):
        def cli(*args):
            if args[0] == "list-windows": return {"windows": []}
            return {"workspaces": [{"workspace": 1, "current": True, "window_count": 1},
                                    {"workspace": 2, "name": "other", "window_count": 1}]}
        state = {"query": "other", "selected": "2"}
        with patch.dict(picker.os.environ, {"TUIOS_SESSION": "test"}), \
             patch.object(picker.sys, "argv", ["tuios-picker", "workspaces"]), \
             patch.object(picker, "cli", side_effect=cli), \
             patch.object(picker, "choose", return_value=("ctrl-x", "2")), \
             patch.object(picker, "confirm_close", return_value=True), \
             patch.object(picker, "finish_close") as finish, patch.object(picker, "close_target") as worker:
            self.assertTrue(picker.main(state))
        finish.assert_called_once_with("workspace", "2", "1", "test")
        worker.assert_not_called()
        self.assertEqual(state["query"], "other")
        self.assertIsNone(state["selected"])

    def test_tree_excludes_popup_and_preserves_workspace_order(self):
        items = [{"workspace": 2, "window_count": 1}, {"workspace": 1, "window_count": 2}]
        panes = [{"workspace": 1, "window_id": "editor", "title": "Editor"},
                 {"workspace": 1, "window_id": "popup"}]
        with patch.dict(picker.os.environ, {"TUIOS_WINDOW_ID": "popup"}):
            rows = picker.workspace_rows(items, panes, {"1"})
        self.assertEqual([r[0] for r in rows], ["2", "1", "pane:1:editor"])
        self.assertFalse(any("pane" in field for field in rows[1]))

    def run_tree(self, key, selected, state):
        def cli(*args):
            if args[0] == "list-workspaces":
                return {"workspaces": [{"workspace": 1, "current": True, "window_count": 1}]}
            if args[0] == "list-windows":
                return {"windows": [{"workspace": 1, "window_id": "editor"}]}
        with patch.dict(picker.os.environ, {"TUIOS_SESSION": "test"}), \
             patch.object(picker.sys, "argv", ["picker", "workspaces"]), \
             patch.object(picker, "cli", side_effect=cli) as commands, \
             patch.object(picker, "choose", return_value=(key, selected)), \
             patch.object(picker, "confirm_close") as confirm:
            result = picker.main(state)
        return result, commands, confirm

    def test_tree_reload_preserves_query_and_collapses_from_child(self):
        import json
        def cli(*args):
            if args[0] == "list-workspaces":
                return {"workspaces": [{"workspace": 1, "name": "dev", "window_count": 1}]}
            return {"windows": [{"workspace": 1, "window_id": "editor", "title": "dev editor"}]}
        with tempfile.TemporaryDirectory() as directory, patch.object(picker, "cli", side_effect=cli):
            path = Path(directory) / "tree.json"
            path.write_text(json.dumps({"expanded": [], "rows": []}))
            output = io.StringIO()
            with redirect_stdout(output):
                picker.toggle_tree("test", str(path), "1", "dev")
            state = json.loads(path.read_text())
            self.assertEqual(state["expanded"], ["1"])
            self.assertEqual(state["rows"][1][0], "pane:1:editor")
            self.assertIn("reload-sync(", output.getvalue())
            self.assertIn("+pos(1)", output.getvalue())
            with redirect_stdout(io.StringIO()):
                picker.toggle_tree("test", str(path), "pane:1:editor", "dev")
            self.assertEqual(json.loads(path.read_text())["expanded"], [])
            self.assertNotIn("pane:1:editor", path.with_suffix(".rows").read_text())

    def test_pane_enter_focuses_but_delete_never_closes_parent(self):
        result, commands, _ = self.run_tree("", "pane:1:editor", {})
        self.assertIsNone(result)
        commands.assert_any_call("focus-window", "editor", "-s", "test")
        with patch.object(picker, "rpc") as close:
            result, commands, confirm = self.run_tree("ctrl-x", "pane:1:editor", {})
        self.assertTrue(result)
        confirm.assert_called_once_with("pane", "editor", 1)
        close.assert_called_once_with("pane.close", pane_id="editor")
        self.assertEqual(commands.call_count, 2)


class SessionHistoryTests(unittest.TestCase):
    def test_tracks_clients_renames_and_skips_deleted_sessions(self):
        sessions = [{"id": name, "name": name} for name in ("A", "B", "C")]
        clients = [{"pid": 1, "client_id": "one", "session": "A"},
                   {"pid": 2, "client_id": "two", "session": "C"}]
        switches = []
        def cli(*args):
            if args[0] == "ls": return sessions
            if args[0] == "list-clients": return clients
            switches.append(args)
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(picker.os.environ, {"XDG_STATE_HOME": directory}), \
             patch.object(picker, "cli", side_effect=cli):
            picker.session_history()
            clients[0]["session"] = "B"
            picker.session_history()
            sessions[0]["name"] = "renamed-A"
            picker.session_history("B")
            self.assertEqual(switches.pop(), ("switch-session", "renamed-A", "--client", "one"))
            clients[0]["session"] = "C"
            picker.session_history()
            sessions.pop(1)  # B was deleted; fall back to A.
            clients.pop(1)
            picker.session_history("C")
            self.assertEqual(switches.pop(), ("switch-session", "renamed-A", "--client", "one"))

    def test_first_attach_and_ambiguous_clients_never_switch(self):
        clients = [{"pid": 1, "client_id": "one", "session": "A"}]
        def cli(*args):
            if args[0] == "ls": return [{"id": "a", "name": "A"}]
            if args[0] == "list-clients": return clients
            self.fail("must not switch")
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(picker.os.environ, {"XDG_STATE_HOME": directory}), \
             patch.object(picker, "cli", side_effect=cli):
            picker.session_history("A")
            clients.append({"pid": 2, "client_id": "two", "session": "A"})
            with self.assertRaises(RuntimeError):
                picker.session_history("A")


class WorkspaceCycleTests(unittest.TestCase):
    def cycle(self, current, step, order=None):
        data = {"order": order, "workspaces": [
            {"workspace": n, "current": n == current, "window_count": int(n in (1, 4)),
             "name": "reserved" if n == 7 else ""} for n in range(1, 10)]}
        with patch.object(picker, "cli", return_value=data) as cli:
            picker.cycle_workspace("test-session", step)
        return cli

    def test_skips_empty_and_wraps_both_directions(self):
        for current, step, expected in [(1, 1, 4), (4, 1, 7), (7, 1, 1), (1, -1, 7)]:
            with self.subTest(current=current, step=step):
                self.cycle(current, step).assert_called_with(
                    "select-workspace", str(expected), "-s", "test-session")

    def test_respects_display_order_and_includes_current_empty_workspace(self):
        self.cycle(4, 1, [7, 4, 1]).assert_called_with("select-workspace", "1", "-s", "test-session")
        self.cycle(3, -1).assert_called_with("select-workspace", "1", "-s", "test-session")

    def test_only_current_workspace_does_not_switch(self):
        with patch.object(picker, "cli", return_value={"workspaces": [
                {"workspace": 1, "current": True}, {"workspace": 2}]}) as cli:
            picker.cycle_workspace("test-session", 1)
        cli.assert_called_once_with("list-workspaces", "-s", "test-session")


class CloseTests(unittest.TestCase):
    def test_current_session_switches_before_killing(self):
        events = []
        def rpc(method, **params):
            events.append(method)
            return {"workspaces": [{"workspace_id": "wa"}, {"workspace_id": "wb"}]}
        def cli(*args):
            events.append(args[0])
            if args[0] == "ls":
                return [{"id": "b", "name": "B"}]
            if args[0] == "list-clients":
                return [{"client_id": "c", "session": "B" if "switch-session" in events else "A"}]
            return {}
        with patch.object(picker, "rpc", side_effect=rpc) as call, patch.object(picker, "cli", side_effect=cli):
            picker.finish_close("session", "wa", "wa", "A")
        self.assertLess(events.index("switch-session"), events.index("workspace.close"))
        call.assert_called_with("workspace.close", workspace_id="wa")

    def test_failed_switch_never_kills_current_session(self):
        def cli(*args):
            if args[0] == "ls":
                return [{"id": "b", "name": "B"}]
            return [{"client_id": "c", "session": "A"}]
        with patch.object(picker, "rpc", return_value={"workspaces": [{"workspace_id": "wa"}, {"workspace_id": "wb"}]}) as call, \
             patch.object(picker, "cli", side_effect=cli), \
             patch.object(picker.time, "monotonic", side_effect=[0, 11]):
            with self.assertRaises(RuntimeError):
                picker.finish_close("session", "wa", "wa", "A")
        self.assertEqual(call.call_count, 1)

    def test_other_session_does_not_switch_client(self):
        with patch.object(picker, "rpc") as rpc, patch.object(picker, "cli") as cli:
            picker.finish_close("session", "wb", "wa", "A")
        cli.assert_not_called()
        rpc.assert_called_once_with("workspace.close", workspace_id="wb")

    def test_workspace_closes_the_selected_tab(self):
        with patch.object(picker, "session_workspace_id", return_value="wa"), \
             patch.object(picker, "rpc", return_value={"tabs": [{"number": 2, "tab_id": "wa:t2"}]}) as rpc:
            picker.finish_close("workspace", "2", "2", "A")
        rpc.assert_called_with("tab.close", tab_id="wa:t2")

    def test_worker_survives_popup_process_group(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(picker.os.environ, {"XDG_STATE_HOME": directory}), \
             patch.object(picker.subprocess, "Popen") as popen:
            picker.close_target("workspace", "2", "2", "A")
        self.assertTrue(popen.call_args.kwargs["start_new_session"])
        self.assertEqual(popen.call_args.kwargs["stdin"], picker.subprocess.DEVNULL)


if __name__ == "__main__":
    unittest.main()
