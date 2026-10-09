import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


loader = importlib.machinery.SourceFileLoader("tuios_picker", str(Path(__file__).resolve().parents[1] / "bin/tuios-picker"))
spec = importlib.util.spec_from_loader(loader.name, loader)
picker = importlib.util.module_from_spec(spec)
loader.exec_module(picker)


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
