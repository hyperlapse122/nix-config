"""Drive t3code-antigravity-link against fake T3 Code base directories.

T3 Code keeps each Antigravity instance's GEMINI_HOME at
<base>/userdata/providers/antigravity/<sha256 of the instance id>. The helper
creates the declared homes and links the CLI's plugins and global instructions
into config/ of every home there.
"""

import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/t3code-antigravity-link"

DEFAULT_KEY = "ac0a3dfd6dddb20962cecff6ee5fe65e19d3923be20e52c5ab52ff877f7e4c32"


class LinkTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.base = self.root / "home/.t3"
        self.gemini = self.root / "home/.gemini/config"
        self.providers = self.base / "userdata/providers/antigravity"

    def tearDown(self):
        self.tmp.cleanup()

    def run_helper(self, *instances):
        args = [str(SCRIPT), "--base-dir", str(self.base), "--gemini-config", str(self.gemini)]
        for instance in instances:
            args += ["--instance", instance]
        return subprocess.run(args, capture_output=True, text=True)

    def home(self, key=DEFAULT_KEY):
        return self.providers / key

    def assert_linked(self, home):
        for name in ("plugins", "AGENTS.md"):
            link = home / "config" / name
            self.assertTrue(link.is_symlink(), link)
            self.assertEqual(os.readlink(link), str(self.gemini / name))

    def make_t3_home(self, key=DEFAULT_KEY):
        home = self.home(key)
        (home / "config").mkdir(parents=True)
        (home / "antigravity-acp").mkdir()
        (home / "antigravity-acp/settings.json").write_text("{}")
        os.symlink("/elsewhere/skills", home / "config/skills")
        os.chmod(home, 0o700)
        return home

    def test_creates_declared_home_with_links(self):
        self.assertEqual(hashlib.sha256(b"antigravity").hexdigest(), DEFAULT_KEY)
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        home = self.home()
        self.assertEqual(home.stat().st_mode & 0o777, 0o700)
        self.assert_linked(home)
        self.assertEqual(len(result.stdout.splitlines()), 2)

    def test_existing_t3_home_keeps_other_entries(self):
        home = self.make_t3_home()
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_linked(home)
        self.assertEqual(os.readlink(home / "config/skills"), "/elsewhere/skills")
        self.assertEqual((home / "antigravity-acp/settings.json").read_text(), "{}")

    def test_undeclared_home_is_linked(self):
        home = self.make_t3_home("f" * 64)
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_linked(home)

    def test_wrong_link_replaced_and_regular_file_left(self):
        home = self.make_t3_home()
        os.symlink("/wrong", home / "config/plugins")
        (home / "config/AGENTS.md").write_text("mine")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(home / "config/plugins"), str(self.gemini / "plugins"))
        self.assertFalse((home / "config/AGENTS.md").is_symlink())
        self.assertEqual((home / "config/AGENTS.md").read_text(), "mine")
        self.assertIn(
            f"t3code-antigravity-link: {home / 'config/AGENTS.md'} is not a link; left as is",
            result.stderr,
        )
        self.assertEqual([p.name for p in (home / "config").iterdir() if p.name.startswith(".")], [])

    def test_nothing_to_do_creates_nothing(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.base / "userdata").exists())

    def test_second_run_changes_nothing(self):
        self.assertEqual(self.run_helper("antigravity").returncode, 0)
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")

    def test_existing_home_keeps_its_mode(self):
        home = self.make_t3_home()
        os.chmod(home, 0o755)
        self.assertEqual(self.run_helper("antigravity").returncode, 0)
        self.assertEqual(home.stat().st_mode & 0o777, 0o755)

    def test_error_exits_one(self):
        self.base.mkdir(parents=True)
        (self.base / "userdata").write_text("not a directory")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stderr.startswith("t3code-antigravity-link: "))


if __name__ == "__main__":
    unittest.main()
