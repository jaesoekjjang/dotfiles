import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
import subprocess
import tempfile
import json
import os
import io
import fcntl
import pty
import select
import shutil
import struct
import termios
import time
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("theme_picker", str(ROOT / "bin/tuios-theme-picker"))
spec = importlib.util.spec_from_loader(loader.name, loader)
picker = importlib.util.module_from_spec(spec)
loader.exec_module(picker)


class ThemePickerTests(unittest.TestCase):
    palettes = {"dayfox": {"dark": False}, "serendipity_morning": {"dark": False},
                "nightfox": {"dark": True}, "misleading_light_name": {"dark": True}}

    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.bundle = Path(directory.name) / "palettes.json"
        self.bundle.write_text(json.dumps({"session": "source", "palettes": self.palettes}))
        environment = patch.dict(os.environ, XDG_CONFIG_HOME=directory.name,
                                 TUIOS_THEME_FAVORITES=str(Path(directory.name) / "shared/theme-favorites.json"))
        environment.start()
        self.addCleanup(environment.stop)

    def test_groups_use_palette_metadata_and_keep_alphabetical_order(self):
        self.assertEqual(picker.group_ids(self.palettes, False),
                         ["dayfox", "serendipity_morning"])
        self.assertEqual(picker.group_ids(self.palettes, True),
                         ["misleading_light_name", "nightfox"])

    def test_reopening_keeps_order_and_focuses_current_theme(self):
        palettes = {name: {"dark": False} for name in "abcde"}
        for original, position in (("c", 3), ("d", 4), ("missing", 1)):
            with self.subTest(original=original), patch.object(
                picker.subprocess, "run",
                return_value=subprocess.CompletedProcess([], 0, "\n\nd\t \n"),
            ) as run:
                picker.choose(palettes, original, False, self.bundle)
            self.assertEqual(run.call_args.kwargs["input"], "a\t \nb\t \nc\t \nd\t \ne\t \n")
            command = run.call_args.args[0]
            self.assertIn("--sync", command)
            self.assertIn(f"--bind=start:pos({position})", command)

    def test_favorites_persist_and_toggle_without_losing_other_names(self):
        self.assertEqual(picker.load_favorites(), set())
        picker.toggle_favorite("dayfox")
        picker.toggle_favorite("nightfox")
        self.assertEqual(json.loads(picker.favorites_path().read_text()), ["dayfox", "nightfox"])
        picker.toggle_favorite("dayfox")
        self.assertEqual(picker.load_favorites(), {"nightfox"})

    def test_default_favorites_live_in_resolved_dotfiles_checkout(self):
        with patch.dict(os.environ, TUIOS_THEME_FAVORITES=""):
            self.assertEqual(picker.favorites_path(), ROOT / "tuios/theme-favorites.json")

    def test_devices_share_updates_and_import_local_favorites_only_once(self):
        shared = picker.favorites_path()
        with tempfile.TemporaryDirectory() as directory:
            for device, theme in (("first", "dayfox"), ("second", "nightfox")):
                config = Path(directory) / device
                legacy = config / "tuios/theme-favorites.json"
                legacy.parent.mkdir(parents=True)
                legacy.write_text(json.dumps([theme]))
                with patch.dict(os.environ, XDG_CONFIG_HOME=str(config)):
                    self.assertIn(theme, picker.load_favorites())
                    self.assertTrue(legacy.with_suffix(".migrated").exists())
                    self.assertEqual(json.loads(legacy.read_text()), [theme])
            self.assertEqual(json.loads(shared.read_text()), ["dayfox", "nightfox"])
            picker.toggle_favorite("dayfox")
            with patch.dict(os.environ, XDG_CONFIG_HOME=str(Path(directory) / "first")):
                self.assertEqual(picker.load_favorites(), {"nightfox"})

    def test_invalid_local_favorites_leave_shared_data_and_migration_untouched(self):
        picker.save_favorites(picker.favorites_path(), {"dayfox"})
        legacy = Path(os.environ["XDG_CONFIG_HOME"]) / "tuios/theme-favorites.json"
        legacy.parent.mkdir(parents=True)
        legacy.write_text('{"invalid": true}')
        with self.assertRaises(ValueError):
            picker.load_favorites()
        self.assertEqual(picker.read_favorites(picker.favorites_path()), {"dayfox"})
        self.assertFalse(legacy.with_suffix(".migrated").exists())

    def test_favorites_view_filters_by_polarity_and_marks_rows(self):
        for theme in ("serendipity_morning", "nightfox", "removed_theme"):
            picker.toggle_favorite(theme)
        with patch.object(picker.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "morning\n\nserendipity_morning\t★\n")) as run:
            result = picker.choose(self.palettes, "serendipity_morning", False,
                                   self.bundle, True, "morning")
        self.assertEqual(run.call_args.kwargs["input"], "serendipity_morning\t★\n")
        self.assertIn("--query=morning", run.call_args.args[0])
        self.assertEqual(result, ("serendipity_morning", "", "morning"))

    def test_empty_favorites_can_return_to_all_themes(self):
        with patch.object(picker.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "\nctrl-g\n")) as run:
            result = picker.choose(self.palettes, "dayfox", False, self.bundle, True)
        self.assertEqual(run.call_args.kwargs["input"], "")
        self.assertEqual(result, (None, "ctrl-g", ""))
        self.assertTrue(any("★ 목록이 비어" in arg for arg in run.call_args.args[0]))

    def test_favorites_refresh_inside_fzf_with_stable_theme_identity(self):
        with patch.object(picker.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 130, "")) as run:
            picker.choose(self.palettes, "dayfox", False, self.bundle)
        command = run.call_args.args[0]
        self.assertIn("--expect=tab", command)
        self.assertIn("--track", command)
        self.assertIn("--id-nth=1", command)
        self.assertTrue(any(arg.startswith("--bind=ctrl-f:reload-sync(") for arg in command))
        self.assertTrue(any(arg.startswith("--bind=ctrl-g:reload-sync(") for arg in command))

    def test_reload_toggles_star_without_reordering_and_handles_empty_favorites(self):
        picker.view_path(self.bundle).write_text(json.dumps({"dark": False, "favorites_only": False}))
        with redirect_stdout(io.StringIO()) as output:
            picker.refresh_rows(self.bundle, "toggle", "serendipity_morning")
        self.assertEqual(output.getvalue(), "dayfox\t \nserendipity_morning\t★\n")
        with redirect_stdout(io.StringIO()) as output:
            picker.refresh_rows(self.bundle, "filter")
        self.assertEqual(output.getvalue(), "serendipity_morning\t★\n")
        with redirect_stdout(io.StringIO()) as output:
            picker.refresh_rows(self.bundle, "toggle", "serendipity_morning")
        self.assertEqual(output.getvalue(), "")
        with redirect_stdout(io.StringIO()) as output:
            picker.refresh_rows(self.bundle, "filter")
        self.assertEqual(output.getvalue(), "dayfox\t \nserendipity_morning\t \n")

    @unittest.skipUnless(shutil.which("fzf"), "fzf is required")
    def test_real_fzf_favorite_toggle_keeps_cursor_and_screen_open(self):
        for original in ('a', 'c', 'e'):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory); result_path = root / 'result.json'; bundle = root / 'palettes.json'
                palettes = {name: {'dark': False} for name in 'abcde'}
                bundle.write_text(json.dumps({'session': 'test', 'palettes': palettes}))
                pid, master = pty.fork()
                if pid == 0:
                    try:
                        os.environ.update(TERM='xterm-256color', XDG_CONFIG_HOME=directory,
                                          TUIOS_THEME_FAVORITES=str(root / 'shared/theme-favorites.json'))
                        real_run = picker.subprocess.run
                        def run(command, **kwargs):
                            command = [arg for arg in command if not arg.startswith('--preview=') and not arg.startswith('--bind=focus:')]
                            return real_run(command, **kwargs)
                        picker.subprocess.run = run
                        result_path.write_text(json.dumps(picker.choose(palettes, original, False, bundle)))
                        os._exit(0)
                    except Exception:
                        os._exit(1)
                fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 140, 0, 0))
                transcript = bytearray()
                def pump_until(predicate):
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        ready, _, _ = select.select([master], [], [], .05)
                        if ready:
                            try: chunk = os.read(master, 65536)
                            except OSError: break
                            transcript.extend(chunk)
                            if b'\x1b[6n' in chunk: os.write(master, b'\x1b[1;1R')
                        if predicate(): return
                    raise AssertionError(('timeout', bytes(transcript[-500:])))
                try:
                    pump_until(lambda: b'Light' in transcript)
                    os.write(master, b'\x06')
                    favorite_file = root / 'shared/theme-favorites.json'
                    pump_until(lambda: favorite_file.exists() and original in json.loads(favorite_file.read_text()))
                    time.sleep(.2)
                    os.write(master, b'\x06')
                    pump_until(lambda: json.loads(favorite_file.read_text()) == [])
                    time.sleep(.2)
                    assert b'\x1b[?1049l' not in transcript, 'fzf left alternate screen while toggling'
                    os.write(master, b'\r')
                    pump_until(result_path.exists)
                    result = tuple(json.loads(result_path.read_text()))
                    self.assertEqual(result, (original, "", ""))
                finally:
                    done, _ = os.waitpid(pid, os.WNOHANG)
                    if not done:
                        os.kill(pid, 15); os.waitpid(pid, 0)
                    os.close(master)

    def test_cancel_after_explicit_toggle_restores_original_without_saving(self):
        with patch.object(picker, "choose", side_effect=[("dayfox", "tab", ""), (None, "", "")]) as choose, \
             patch.object(picker, "apply_theme") as apply, patch.object(picker, "commit_theme") as save:
            picker.browse("source", self.palettes, "dayfox")
        self.assertEqual([call.args[2] for call in choose.call_args_list], [False, True])
        apply.assert_called_once_with("source", "dayfox")
        save.assert_not_called()

    def test_accept_applies_and_saves_selected_theme(self):
        with patch.object(picker, "choose", return_value=("serendipity_morning", "", "")), \
             patch.object(picker, "apply_theme") as apply, patch.object(picker, "commit_theme") as save:
            picker.browse("source", self.palettes, "dayfox")
        apply.assert_not_called()
        save.assert_called_once_with("source", "serendipity_morning")

    def test_failed_save_rolls_preview_back(self):
        with patch.object(picker, "choose", return_value=("serendipity_morning", "", "")), \
             patch.object(picker, "apply_theme") as apply, \
             patch.object(picker, "commit_theme", side_effect=OSError("write failed")):
            with self.assertRaises(OSError):
                picker.browse("source", self.palettes, "dayfox")
        self.assertEqual([call.args for call in apply.call_args_list],
                         [("source", "dayfox")])

    def test_commit_refuses_recorded_but_not_applied_response(self):
        with patch.object(picker, "rpc", return_value={"applied": False, "reason": "no attached client"}):
            with self.assertRaisesRegex(RuntimeError, "no attached client"):
                picker.commit_theme("source", "dayfox")

    def test_original_theme_reads_attached_client_not_daemon_default(self):
        with patch.object(picker.subprocess, "check_output", return_value='{"value":"dayfox"}') as read:
            self.assertEqual(picker.original_theme("source"), "dayfox")
        self.assertEqual(read.call_args.args[0],
                         ["tuios", "get-config", "appearance.theme", "-s", "source", "--json"])

    def test_preview_uses_runtime_command_without_settings_write(self):
        with patch.object(picker, "rpc", return_value={"routed": True}) as call:
            picker.apply_theme("source", "dayfox")
        call.assert_called_once_with("run-command", {
            "session": "source", "command": "SetTheme", "args": ["dayfox"]})


if __name__ == "__main__":
    unittest.main()
