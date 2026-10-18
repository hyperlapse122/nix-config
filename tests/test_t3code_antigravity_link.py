"""Drive t3code-antigravity-link against fake T3 Code base directories.

T3 Code keeps each Antigravity instance's GEMINI_HOME at
<base>/userdata/providers/antigravity/<sha256 of the instance id>. The helper
creates the declared homes and removes the config/ links an earlier version made
in every home there. It links each plugin skill into ~/.gemini/antigravity-cli/skills,
which T3 Code links into every home itself, because the ACP runtime loads skills
but not plugins.
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
        self.cli_skills = self.root / "home/.gemini/antigravity-cli/skills"
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
        self.assertTrue((home / "config").is_dir(), home)
        self.assertFalse(os.path.lexists(home / "config/AGENTS.md"))
        self.assertFalse(os.path.lexists(home / "config/plugins"))

    def make_plugin_skill(self, plugin, name):
        skill = self.gemini / "plugins" / plugin / "skills" / name
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(f"---\nname: {name}\n---\n")
        return skill

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
        self.assertEqual(result.stdout, "")

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

    def test_old_instructions_link_is_removed(self):
        home = self.make_t3_home()
        os.symlink(self.gemini / "AGENTS.md", home / "config/AGENTS.md")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_linked(home)
        self.assertIn(f"removed {home / 'config/AGENTS.md'}", result.stdout)

    def test_foreign_instructions_link_is_left(self):
        home = self.make_t3_home()
        os.symlink("/elsewhere/AGENTS.md", home / "config/AGENTS.md")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(home / "config/AGENTS.md"), "/elsewhere/AGENTS.md")

    def test_regular_file_left(self):
        home = self.make_t3_home()
        (home / "config/AGENTS.md").write_text("mine")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((home / "config/AGENTS.md").is_symlink())
        self.assertEqual((home / "config/AGENTS.md").read_text(), "mine")
        self.assertIn(
            f"t3code-antigravity-link: {home / 'config/AGENTS.md'} is not a link; left as is",
            result.stderr,
        )

    def test_runtime_ignored_plugins_link_is_removed(self):
        # agy_acp_server.par reads no config/plugins, so the link an earlier
        # helper made there only suggested the plugins reached T3 Code.
        home = self.make_t3_home()
        os.symlink(self.gemini / "plugins", home / "config/plugins")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_linked(home)
        self.assertIn(f"removed {home / 'config/plugins'}", result.stdout)

    def test_foreign_plugins_entry_is_left(self):
        home = self.make_t3_home()
        os.symlink("/elsewhere/plugins", home / "config/plugins")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(home / "config/plugins"), "/elsewhere/plugins")

    def test_plugin_skills_are_linked_where_the_runtime_loads_skills(self):
        first = self.make_plugin_skill("compound-engineering", "ce-plan")
        second = self.make_plugin_skill("compound-engineering", "ce-work")
        (self.gemini / "plugins/compound-engineering/skills/notes").mkdir()
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted(p.name for p in self.cli_skills.iterdir()), ["ce-plan", "ce-work"])
        self.assertEqual(os.readlink(self.cli_skills / "ce-plan"), str(first))
        self.assertEqual(os.readlink(self.cli_skills / "ce-work"), str(second))
        self.assertIn(f"linked {self.cli_skills / 'ce-plan'}", result.stdout)

    def test_plugin_skills_need_no_instance_home(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cli_skills / "ce-plan").is_symlink())

    def test_stale_plugin_skill_link_is_removed(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
        self.cli_skills.mkdir(parents=True)
        gone = self.cli_skills / "ce-gone"
        os.symlink(self.gemini / "plugins/compound-engineering/skills/ce-gone", gone)
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(os.path.lexists(gone))
        self.assertIn(f"removed {gone}", result.stdout)

    def test_user_skills_are_left(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
        self.make_plugin_skill("compound-engineering", "ce-work")
        self.cli_skills.mkdir(parents=True)
        (self.cli_skills / "mine").mkdir()
        os.symlink("/elsewhere/other", self.cli_skills / "other")
        (self.cli_skills / "ce-plan").mkdir()
        os.symlink("/elsewhere/ce-work", self.cli_skills / "ce-work")
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cli_skills / "mine").is_dir())
        self.assertEqual(os.readlink(self.cli_skills / "other"), "/elsewhere/other")
        self.assertFalse((self.cli_skills / "ce-plan").is_symlink())
        self.assertEqual(os.readlink(self.cli_skills / "ce-work"), "/elsewhere/ce-work")
        for name in ("ce-plan", "ce-work"):
            self.assertIn(f"{self.cli_skills / name} is not a plugin skill link; left as is", result.stderr)

    def test_same_skill_name_in_two_plugins_fails_after_linking_the_first(self):
        # One name can hold one link, so the second plugin's skill would be
        # missing from every session; the run fails so activation reports it.
        first = self.make_plugin_skill("alpha", "shared")
        second = self.make_plugin_skill("beta", "shared")
        other = self.make_plugin_skill("beta", "other")
        result = self.run_helper()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(os.readlink(self.cli_skills / "shared"), str(first))
        self.assertEqual(os.readlink(self.cli_skills / "other"), str(other))
        self.assertIn(f"skill shared is in more than one plugin: {first} and {second}", result.stderr)

    def test_last_plugin_removed_prunes_its_links(self):
        self.cli_skills.mkdir(parents=True)
        gone = self.cli_skills / "ce-gone"
        os.symlink(self.gemini / "plugins/compound-engineering/skills/ce-gone", gone)
        (self.cli_skills / "mine").mkdir()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(os.path.lexists(gone))
        self.assertTrue((self.cli_skills / "mine").is_dir())
        self.assertIn(f"removed {gone}", result.stdout)

    def test_disabled_plugin_skills_are_not_linked(self):
        # agy plugin disable records enablement in config.json and keeps the tree.
        self.make_plugin_skill("compound-engineering", "ce-plan")
        kept = self.make_plugin_skill("other", "kept")
        self.cli_skills.mkdir(parents=True)
        os.symlink(self.gemini / "plugins/compound-engineering/skills/ce-plan", self.cli_skills / "ce-plan")
        (self.gemini / "config.json").write_text(
            '{"plugins": {"compound-engineering": {"enabled": false}, "other": {"enabled": true}}}'
        )
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(os.path.lexists(self.cli_skills / "ce-plan"))
        self.assertEqual(os.readlink(self.cli_skills / "kept"), str(kept))

    def test_malformed_plugin_config_fails_and_changes_no_skill_link(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
        (self.gemini / "config.json").write_text("{not json")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.cli_skills.exists())
        self.assertIn(f"t3code-antigravity-link: {self.gemini / 'config.json'}", result.stderr)
        self.assert_linked(self.home())

    def test_skill_link_failure_exits_one(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
        self.cli_skills.parent.parent.mkdir(parents=True, exist_ok=True)
        self.cli_skills.parent.write_text("not a directory")
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stderr.startswith("t3code-antigravity-link: "))
        self.assert_linked(self.home())

    def test_nothing_to_do_creates_nothing(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.base / "userdata").exists())
        self.assertFalse(self.cli_skills.exists())

    def test_second_run_changes_nothing(self):
        self.make_plugin_skill("compound-engineering", "ce-plan")
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

    def broken_home(self, key):
        home = self.home(key)
        home.mkdir(parents=True)
        (home / "config").write_text("not a directory")
        return home

    def test_failing_undeclared_home_is_reported_and_skipped(self):
        self.broken_home("0" * 64)
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_linked(self.home())
        self.assertIn(str(self.home("0" * 64) / "config"), result.stderr)

    def test_failing_declared_home_fails_after_linking_the_rest(self):
        self.broken_home(DEFAULT_KEY)
        other = self.make_t3_home("f" * 64)
        result = self.run_helper("antigravity")
        self.assertEqual(result.returncode, 1)
        self.assert_linked(other)
        self.assertTrue(result.stderr.startswith("t3code-antigravity-link: "))


if __name__ == "__main__":
    unittest.main()
