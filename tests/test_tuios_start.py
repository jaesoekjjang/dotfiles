import os
import pwd
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TuiosStartTests(unittest.TestCase):
    def launch(self, installed, macos_login=False):
        with tempfile.TemporaryDirectory(prefix="tuios-start with spaces-") as directory:
            root = Path(directory)
            tools = root / "bin"
            tools.mkdir()
            if installed:
                binary = tools / "tuios"
                binary.write_text('#!/bin/sh\nprintf "tuios:%s\\n" "$*"\n')
                binary.chmod(0o755)
            # Override only shell startup files, not the user's home directory.
            (root / ".zprofile").write_text("export PATH=" + shlex.quote(str(tools)) + "\n")
            command = next(line.split("=", 1)[1].strip() for line in
                           (ROOT / "ghostty/config").read_text().splitlines()
                           if line.startswith("command ="))
            self.assertTrue(command.startswith("shell:"))
            command = command.removeprefix("shell:").replace(
                "~/.local/bin/tuios-start", shlex.quote(str(ROOT / "bin/tuios-start")))
            argv = ["/bin/sh", "-c", command]
            if macos_login:
                argv = ["/usr/bin/login", "-flp", pwd.getpwuid(os.getuid()).pw_name,
                        "/bin/bash", "--noprofile", "--norc", "-c", "exec -l " + command]
            return subprocess.run(argv,
                                  env=dict(os.environ, ZDOTDIR=str(root)),
                                  input="print fallback-shell-ok\n", text=True,
                                  capture_output=True, timeout=10, check=True)

    def test_ghostty_shell_command_attaches_without_literal_quotes(self):
        self.assertEqual(self.launch(True).stdout.strip(), "tuios:attach")

    def test_missing_tuios_starts_a_login_shell(self):
        self.assertEqual(self.launch(False).stdout.strip(), "fallback-shell-ok")

    @unittest.skipUnless(Path("/usr/bin/login").exists() and sys.platform == "darwin", "macOS login wrapper")
    def test_ghostty_macos_login_wrapper_attaches(self):
        result = self.launch(True, macos_login=True)
        self.assertIn("tuios:attach", result.stdout)
        self.assertNotIn("exec: not found", result.stderr)


if __name__ == "__main__":
    unittest.main()
