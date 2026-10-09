"""Exercise bootstrap with a disposable HOME; no host package installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home with spaces"
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), DOTFILES="/old/checkout")

    def setup(self, *args):
        return subprocess.run(["/bin/zsh", str(ROOT / "setup.zsh"), *args],
                              env=self.env, capture_output=True, text=True, check=True)

    def test_links_are_relocatable_and_preserve_terminal(self):
        self.setup()
        env = dict(self.env, TERM="custom-terminal")
        output = subprocess.check_output(
            ["/bin/zsh", "-f", "-c", 'source "$HOME/.zshenv"; print -r -- "$DOTFILES|$TERM"'],
            env=env, text=True)
        self.assertEqual(output.strip(), f"{ROOT}|custom-terminal")
        self.assertEqual((self.home / ".secrets.zsh").stat().st_mode & 0o777, 0o600)

    def test_existing_config_is_backed_up_only_once(self):
        (self.home / ".zshrc").write_text("personal shell settings")
        (self.home / ".p10k.zsh").write_text("personal prompt")
        self.setup()
        self.setup()
        copies = list((self.home / ".local/state/dotfiles-backups").rglob(".zshrc-*"))
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0].read_text(), "personal shell settings")
        self.assertEqual((self.home / ".p10k.zsh").read_text(), "personal prompt")

    def test_tuios_link_migrates_without_losing_local_content(self):
        source = self.home / "custom.toml"
        source.write_text("personal TUIOS settings")
        runtime = self.home / "Library/Application Support/tuios/config.toml"
        runtime.parent.mkdir(parents=True)
        runtime.symlink_to(source)
        self.setup()
        self.assertFalse(runtime.is_symlink())
        self.assertEqual(runtime.read_text(), "personal TUIOS settings")
        runtime.write_text("changed in Settings")
        self.setup()
        self.assertEqual(runtime.read_text(), "changed in Settings")
        self.setup("--refresh-tuios")
        self.assertEqual(runtime.read_bytes(), (ROOT / "tuios/config.toml").read_bytes())
        backups = list((self.home / ".local/state/dotfiles-backups").rglob("config.toml-*"))
        self.assertTrue(any(p.is_file() and p.read_text() == "changed in Settings" for p in backups))
        self.assertEqual(source.read_text(), "personal TUIOS settings")

    def test_installer_provisions_node_before_npm_and_preserves_plugins(self):
        binaries = self.home / "fake-bin"
        binaries.mkdir()
        node_bin = self.home / "node-bin"
        node_bin.mkdir()
        capture = self.home / "calls.jsonl"
        driver = binaries / "driver.py"
        driver.write_text('''import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CAPTURE"], "a") as f: f.write(json.dumps([name, *args])+"\\n")
if name == "brew" and args == ["shellenv"]: print(":")
elif name == "fnm" and args[0] == "env":
    print('export PATH="'+os.environ["NODE_BIN"]+':$PATH"')
elif name == "fnm" and args[0] == "install":
    d = pathlib.Path(os.environ["NODE_BIN"])
    (d / "node").write_text("#!/bin/sh\\necho v24.0.0\\n")
    (d / "node").chmod(0o755)
    for tool in ["npm", "corepack"]: (d / tool).symlink_to(os.environ["DRIVER"])
elif name == "git" and args[-2:] == ["init", "-q"]:
    (pathlib.Path(args[1]) / ".git").mkdir()
''')
        # A symlinked script sees the invoked tool name in argv[0].
        driver.write_text("#!" + shutil.which("python3") + "\n" + driver.read_text())
        driver.chmod(0o755)
        for tool in ["brew", "fnm", "git", "xcode-select", "uv", "python3"]:
            (binaries / tool).symlink_to(driver)
        existing = self.home / ".oh-my-zsh"
        existing.mkdir()
        (existing / "personal").write_text("keep me")
        env = dict(self.env, PATH=f"{binaries}:/usr/bin:/bin", CAPTURE=str(capture),
                   NODE_BIN=str(node_bin), DRIVER=str(driver))
        subprocess.run(["/bin/zsh", str(ROOT / "install.zsh"), "--cli-only", "--no-agents"],
                       env=env, capture_output=True, text=True, check=True)
        calls = [json.loads(line) for line in capture.read_text().splitlines()]
        self.assertIn(["uv", "python", "install", "3.13", "--default"], calls)
        node_install = next(i for i, c in enumerate(calls) if c[:2] == ["fnm", "install"])
        npm_install = next(i for i, c in enumerate(calls) if c[:2] == ["npm", "install"])
        self.assertLess(node_install, npm_install)
        self.assertFalse(any("Brewfile.desktop" in arg or "Brewfile.languages" in arg for c in calls for arg in c))
        self.assertEqual((existing / "personal").read_text(), "keep me")


if __name__ == "__main__":
    unittest.main()
