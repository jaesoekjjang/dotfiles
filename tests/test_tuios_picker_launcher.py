"""The picker itself is covered by Go tests; exercise its relocatable launcher."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PickerLauncherTests(unittest.TestCase):
    def test_build_cache_symlink_relocation_and_source_updates(self):
        with tempfile.TemporaryDirectory(prefix="picker-launcher-") as directory:
            directory = str(Path(directory).resolve())
            root = Path(directory) / "checkout with spaces"
            (root / "bin").mkdir(parents=True)
            module = root / "tuios/picker"
            module.mkdir(parents=True)
            shutil.copy2(ROOT / "bin/tuios-picker", root / "bin/tuios-picker")
            for name in ["go.mod", "go.sum", "main.go"]:
                (module / name).write_text("fixture")
            fake_bin = Path(directory) / "fake-bin"
            fake_bin.mkdir()
            fake_go = fake_bin / "go"
            fake_go.write_text('''#!/bin/zsh
print build >> "$CAPTURE"
while (( $# )); do
  if [[ "$1" == -o ]]; then
    print '#!/bin/zsh' > "$2"
    print 'print -r -- "$TUIOS_PICKER_TRIAL|$PWD|$*"' >> "$2"
    chmod +x "$2"
    exit
  fi
  shift
done
exit 1
''')
            fake_go.chmod(0o755)
            launcher = Path(directory) / "picker-link"
            launcher.symlink_to(root / "bin/tuios-picker")
            capture = Path(directory) / "builds"
            env = dict(os.environ, PATH=f"{fake_bin}:/usr/bin:/bin",
                       HOME=directory,
                       XDG_CACHE_HOME=str(Path(directory) / "cache with spaces"),
                       CAPTURE=str(capture))
            def run():
                return subprocess.check_output([str(launcher), "workspaces"],
                                               env=env, cwd=directory, text=True)
            expected = f"{root}/bin/tuios-trial|{directory}|workspaces\n"
            self.assertEqual(run(), expected)
            self.assertEqual(run(), expected)
            self.assertEqual(capture.read_text().splitlines(), ["build"])
            (module / "main.go").write_text("updated")
            self.assertEqual(run(), expected)
            self.assertEqual(capture.read_text().splitlines(), ["build", "build"])
            self.assertFalse(list(Path(env["XDG_CACHE_HOME"]).rglob(".build.*")))


if __name__ == "__main__":
    unittest.main()
