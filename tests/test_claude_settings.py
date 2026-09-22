"""Check interface:

    python tests/test_claude_settings.py

Exercises scripts/claude-settings against a seeded settings file.

The fixture starts divergent on purpose: declared keys hold values other than
the declared ones, and undeclared keys sit beside them.  A fixture that already
held the declared values would let a whole-file writer and a correct merger
produce byte-identical output, so the round could not tell them apart.  See
.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md
"""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/claude-settings'
loader = importlib.machinery.SourceFileLoader('claude_settings', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
merger = importlib.util.module_from_spec(spec)
loader.exec_module(merger)

DECLARED = {
    'model': 'opus[1m]',
    'effortLevel': 'medium',
    'language': 'korean',
    'theme': 'dark-ansi',
}

# Declared keys hold other values; the rest is state only the agent writes.
EXISTING = {
    'model': 'sonnet',
    'effortLevel': 'xhigh',
    'theme': 'light',
    'themePreference': 'keep-me',
    'statusLine': {'type': 'command', 'command': 'true'},
    'enabledPlugins': {'example@marketplace': True},
    'numStartups': 41,
}


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / 'home'
        self.settings = self.home / '.claude/settings.json'
        self.declared = Path(self.tmp.name) / 'declared.json'
        self.declared.write_text(json.dumps(DECLARED))

    def seed(self, data=None):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(json.dumps(data if data is not None else EXISTING, indent=2))
        self.settings.chmod(0o600)

    def merge(self):
        merger.merge(self.settings, self.declared)

    def read(self):
        return json.loads(self.settings.read_text())

    def test_declared_keys_reassert_and_undeclared_keys_survive(self):
        self.seed()
        self.merge()
        result = self.read()
        for key, value in DECLARED.items():
            self.assertEqual(result[key], value)
        for key in ['themePreference', 'statusLine', 'enabledPlugins', 'numStartups']:
            self.assertEqual(result[key], EXISTING[key])

    def test_prefix_collision_leaves_the_longer_key_alone(self):
        self.seed()
        self.merge()
        # 'theme' is declared; 'themePreference' merely starts with it.
        self.assertEqual(self.read()['themePreference'], 'keep-me')

    def test_second_run_does_not_rewrite_the_file(self):
        self.seed()
        self.merge()
        before = self.settings.stat()
        self.merge()
        after = self.settings.stat()
        self.assertEqual(before.st_ino, after.st_ino)
        self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)

    def test_creates_file_and_private_parent_when_absent(self):
        self.merge()
        self.assertEqual(self.read(), DECLARED)
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.settings.parent.stat().st_mode & 0o777, 0o700)

    def test_refuses_a_symlinked_settings_path(self):
        self.settings.parent.mkdir(parents=True)
        target = Path(self.tmp.name) / 'elsewhere.json'
        target.write_text(json.dumps({'model': 'untouched'}))
        self.settings.symlink_to(target)
        with self.assertRaises(ValueError):
            self.merge()
        self.assertTrue(self.settings.is_symlink())
        self.assertEqual(json.loads(target.read_text()), {'model': 'untouched'})

    def test_refuses_a_symlinked_parent_directory(self):
        elsewhere = Path(self.tmp.name) / 'elsewhere'
        elsewhere.mkdir()
        self.home.mkdir()
        self.settings.parent.symlink_to(elsewhere)
        with self.assertRaises(ValueError):
            self.merge()

    def test_refuses_malformed_json_without_touching_the_file(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('{ not json')
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.settings.read_text(), '{ not json')

    def test_refuses_settings_that_are_valid_json_but_not_an_object(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('[]')
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.settings.read_text(), '[]')

    def test_refuses_declared_settings_that_are_not_an_object(self):
        self.seed()
        self.declared.write_text('["model"]')
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.read(), EXISTING)

    def test_refuses_an_object_valued_declaration(self):
        # Assignment is one level deep, so declaring an object would replace
        # the user's whole object rather than merging into it.
        self.seed()
        self.declared.write_text(json.dumps({'permissions': {'allow': ['Bash']}}))
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.read(), EXISTING)

    def test_tightens_an_existing_loose_parent_directory(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.parent.chmod(0o755)
        self.seed()
        self.merge()
        self.assertEqual(self.settings.parent.stat().st_mode & 0o777, 0o700)

    def test_removes_the_temporary_file_when_the_replace_fails(self):
        self.seed()
        with mock.patch.object(merger.os, 'replace', side_effect=OSError('nope')):
            with self.assertRaises(OSError):
                self.merge()
        leftovers = [p.name for p in self.settings.parent.iterdir() if p.name != 'settings.json']
        self.assertEqual(leftovers, [])
        self.assertEqual(self.read(), EXISTING)

    def test_restores_a_declared_key_the_user_removed(self):
        self.seed({'numStartups': 41})
        self.merge()
        result = self.read()
        self.assertEqual(result['model'], 'opus[1m]')
        self.assertEqual(result['numStartups'], 41)

    def test_leaves_no_temporary_file_behind(self):
        self.seed()
        self.merge()
        leftovers = [p.name for p in self.settings.parent.iterdir() if p.name != 'settings.json']
        self.assertEqual(leftovers, [])

    def test_main_reports_refusal_without_a_traceback(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('{ not json')
        code = merger.main(['--settings', str(self.settings), '--declared', str(self.declared)])
        self.assertEqual(code, 1)

    def test_main_returns_zero_on_success(self):
        self.seed()
        code = merger.main(['--settings', str(self.settings), '--declared', str(self.declared)])
        self.assertEqual(code, 0)
        self.assertEqual(self.read()['model'], 'opus[1m]')

    def run_script(self):
        # Importing the module skips `if __name__ == '__main__': sys.exit(main())`
        # entirely, so the link between a refusal and a non-zero process status
        # is only observable by running the script the way activation does.
        return subprocess.run(
            [sys.executable, str(SCRIPT),
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)

    def test_process_exits_zero_and_merges_on_success(self):
        self.seed()
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.read()['model'], 'opus[1m]')

    def test_process_exits_non_zero_and_names_the_path_on_refusal(self):
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('{ not json')
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(str(self.settings), result.stderr)
        self.assertEqual(self.settings.read_text(), '{ not json')

    def test_refuses_to_run_as_root(self):
        # Patch the euid rather than reading the ambient one: a test that only
        # asserts the non-root path can never go red for a removed guard.
        self.seed()
        with mock.patch.object(merger.os, 'geteuid', return_value=0):
            with self.assertRaises(SystemExit) as raised:
                merger.main(['--settings', str(self.settings),
                             '--declared', str(self.declared)])
        self.assertEqual(raised.exception.code, 2)
        self.assertEqual(self.read(), EXISTING)


if __name__ == '__main__':
    unittest.main()
