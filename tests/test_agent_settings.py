"""Check interface:

    python tests/test_agent_settings.py

Exercises scripts/agent-settings against a seeded settings file.

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

import tomlkit

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/agent-settings'
loader = importlib.machinery.SourceFileLoader('agent_settings', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
merger = importlib.util.module_from_spec(spec)
loader.exec_module(merger)

DECLARED = {
    'model': 'opus[1m]',
    'effortLevel': 'medium',
    'language': 'korean',
    'theme': 'auto',
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
        self.declare(DECLARED)

    def declare(self, assign, remove=None):
        self.declared.write_text(json.dumps({'set': assign, 'remove': remove or []}))

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
        self.declare({'permissions': {'allow': ['Bash']}})
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.read(), EXISTING)

    def test_refuses_a_remove_list_that_is_not_names(self):
        self.seed()
        self.declare(DECLARED, remove=[{'model': True}])
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.read(), EXISTING)

    def test_refuses_a_key_declared_as_both_set_and_removed(self):
        self.seed()
        self.declare(DECLARED, remove=['model'])
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.read(), EXISTING)

    def test_retired_key_is_dropped_and_others_survive(self):
        self.seed()
        self.declare(DECLARED, remove=['themePreference'])
        self.merge()
        result = self.read()
        self.assertNotIn('themePreference', result)
        self.assertEqual(result['numStartups'], EXISTING['numStartups'])
        self.assertEqual(result['model'], DECLARED['model'])

    def test_retiring_an_absent_key_is_a_no_op(self):
        self.seed()
        self.merge()
        before = self.settings.stat().st_mtime_ns
        self.declare(DECLARED, remove=['neverPresent'])
        self.merge()
        self.assertEqual(self.settings.stat().st_mtime_ns, before)

    def test_preserves_a_write_that_lands_while_merging(self):
        # The file has another writer. A plain read-modify-write would discard
        # whatever the agent wrote between the read and the replace.
        self.seed()
        original = merger.read_settings

        calls = []

        def read_then_interfere(path):
            current = original(path)
            calls.append(None)
            # Interfere on the merge loop's first read, not the validation
            # read that precedes it, so this exercises the compare-and-swap.
            if len(calls) == 2:
                concurrent = dict(current)
                concurrent['writtenByTheAgent'] = 'keep me'
                path.write_text(json.dumps(concurrent))
            return current

        with mock.patch.object(merger, 'read_settings', read_then_interfere):
            self.merge()
        result = self.read()
        self.assertEqual(result['writtenByTheAgent'], 'keep me')
        self.assertEqual(result['model'], DECLARED['model'])

    def test_gives_up_when_the_file_never_settles(self):
        self.seed()
        original = merger.read_settings

        def read_then_interfere(path):
            current = original(path)
            churn = dict(current)
            churn['churn'] = os.urandom(4).hex()
            path.write_text(json.dumps(churn))
            return current

        with mock.patch.object(merger, 'read_settings', read_then_interfere):
            with self.assertRaises(ValueError):
                self.merge()

    def test_keeps_non_ascii_text_as_written(self):
        # The interface language here is Korean, so non-ASCII in an undeclared
        # value is expected. ensure_ascii would rewrite it to \uXXXX escapes on
        # every activation, and a locale-dependent read could fail outright.
        self.seed(dict(EXISTING, koreanNote='한글 설정'))
        self.merge()
        raw = self.settings.read_text(encoding='utf-8')
        self.assertIn('한글 설정', raw)
        self.assertNotIn('\\ud55c', raw)

    def test_survives_the_file_disappearing_after_the_snapshot(self):
        self.seed(dict(DECLARED))
        original = merger.read_settings

        def read_then_delete(path):
            current = original(path)
            if not getattr(read_then_delete, 'fired', False):
                read_then_delete.fired = True
                path.unlink()
            return current

        with mock.patch.object(merger, 'read_settings', read_then_delete):
            self.merge()
        self.assertEqual(self.read(), DECLARED)

    def test_refusal_does_not_create_or_tighten_the_parent(self):
        # A refusal must leave the disk as it found it, including the parent.
        self.settings.parent.mkdir(parents=True)
        self.settings.parent.chmod(0o755)
        self.settings.write_text('{ not json')
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.settings.parent.stat().st_mode & 0o777, 0o755)

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

    def test_refusal_names_the_agent_the_caller_labelled(self):
        # Two agents share this merger, so a failure in the rebuild log has to
        # say which file it was about.
        self.settings.parent.mkdir(parents=True)
        self.settings.write_text('{ not json')
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--label', 'Antigravity CLI',
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Antigravity CLI settings merge failed', result.stderr)

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



# Tokscale nests preferences one level down, beside runtime state it writes
# itself.  Every nested object below already carries siblings the declaration
# does not name, and the declared leaves start at other values, so a merger that
# replaced the whole object would lose a key rather than coincide with the fix.
NESTED_EXISTING = {
    'colorPalette': 'green',
    'scanner': {'opencodeDbPaths': ['x'], 'bucketTimezone': 'UTC'},
    'autosubmit': {'enabled': True, 'lastRunAtMs': 1700000000000, 'lastError': 'timeout'},
    'scanner.bucketTimezone': 'literal top-level key',
    'usage': {'daily': [1, 2, 3]},
}

NESTED_PATHS = [
    {'path': ['scanner', 'bucketTimezone'], 'value': 'Asia/Seoul'},
    {'path': ['autosubmit', 'enabled'], 'value': False},
]


class NestedPathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings = Path(self.tmp.name) / 'home/.config/tokscale/settings.json'
        self.declared = Path(self.tmp.name) / 'declared.json'
        self.declare(NESTED_PATHS, assign={'colorPalette': 'blue'})

    def declare(self, paths, assign=None, remove=None):
        self.declared.write_text(json.dumps(
            {'set': assign or {}, 'remove': remove or [], 'setPaths': paths}))

    def seed(self, data=None):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(json.dumps(data if data is not None else NESTED_EXISTING, indent=2))
        self.settings.chmod(0o600)

    def merge(self):
        merger.merge(self.settings, self.declared)

    def read(self):
        return json.loads(self.settings.read_text())

    def assert_refused_untouched(self, *needles):
        before = self.settings.read_bytes()
        with self.assertRaises(ValueError) as raised:
            self.merge()
        self.assertEqual(self.settings.read_bytes(), before)
        for needle in needles:
            self.assertIn(needle, str(raised.exception))

    def test_nested_leaf_reasserts_and_its_siblings_survive(self):
        self.seed()
        self.merge()
        result = self.read()
        self.assertEqual(result['scanner'], {'opencodeDbPaths': ['x'], 'bucketTimezone': 'Asia/Seoul'})
        self.assertEqual(result['colorPalette'], 'blue')
        self.assertEqual(result['usage'], NESTED_EXISTING['usage'])

    def test_missing_intermediate_object_is_created_with_only_the_leaf(self):
        self.seed({'colorPalette': 'green'})
        self.declare([{'path': ['autosubmit', 'enabled'], 'value': False}])
        self.merge()
        self.assertEqual(self.read(), {'colorPalette': 'green', 'autosubmit': {'enabled': False}})

    def test_runtime_state_beside_a_reasserted_leaf_survives(self):
        self.seed()
        self.merge()
        self.assertEqual(self.read()['autosubmit'],
                         {'enabled': False, 'lastRunAtMs': 1700000000000, 'lastError': 'timeout'})

    def test_creates_the_file_when_absent(self):
        self.merge()
        self.assertEqual(self.read(), {
            'colorPalette': 'blue',
            'scanner': {'bucketTimezone': 'Asia/Seoul'},
            'autosubmit': {'enabled': False},
        })

    def test_refuses_a_non_object_intermediate_and_names_the_path(self):
        self.seed(dict(NESTED_EXISTING, scanner='flat'))
        self.assert_refused_untouched('["scanner", "bucketTimezone"]')

    def test_refuses_a_null_intermediate(self):
        # null is not an object either; replacing it would discard a value
        # the owner wrote on purpose.
        self.seed(dict(NESTED_EXISTING, scanner=None))
        self.assert_refused_untouched('["scanner", "bucketTimezone"]')

    def test_non_object_intermediate_refusal_does_not_tighten_the_parent(self):
        self.seed(dict(NESTED_EXISTING, scanner='flat'))
        self.settings.parent.chmod(0o755)
        with self.assertRaises(ValueError):
            self.merge()
        self.assertEqual(self.settings.parent.stat().st_mode & 0o777, 0o755)

    def test_a_dotted_top_level_key_is_neither_read_nor_written(self):
        self.seed()
        self.merge()
        self.assertEqual(self.read()['scanner.bucketTimezone'], 'literal top-level key')
        # A literal dotted key is also not taken as the object to merge into.
        self.seed({'scanner.bucketTimezone': 'UTC'})
        self.merge()
        result = self.read()
        self.assertEqual(result['scanner.bucketTimezone'], 'UTC')
        self.assertEqual(result['scanner'], {'bucketTimezone': 'Asia/Seoul'})

    def test_a_segment_containing_a_dot_is_one_key(self):
        self.seed({'a': {'b': 1}})
        self.declare([{'path': ['a.b', 'c'], 'value': 2}])
        self.merge()
        self.assertEqual(self.read(), {'a': {'b': 1}, 'a.b': {'c': 2}})

    def test_deeper_paths_merge_at_every_level(self):
        self.seed({'a': {'keep': 1, 'b': {'keep': 2, 'c': 'old'}}})
        self.declare([{'path': ['a', 'b', 'c'], 'value': 'new'}])
        self.merge()
        self.assertEqual(self.read(), {'a': {'keep': 1, 'b': {'keep': 2, 'c': 'new'}}})

    def test_refuses_object_and_list_values(self):
        self.seed()
        for value in ({'bucketTimezone': 'Asia/Seoul'}, ['Asia/Seoul']):
            with self.subTest(value=value):
                self.declare([{'path': ['scanner'], 'value': value}])
                self.assert_refused_untouched('["scanner"]')

    def test_refuses_malformed_path_entries(self):
        self.seed()
        cases = [
            'not a list',
            ['not an entry'],
            [{'path': [], 'value': 1}],
            [{'path': 'scanner.bucketTimezone', 'value': 1}],
            [{'path': ['scanner', 3], 'value': 1}],
            [{'path': ['scanner', 'bucketTimezone']}],
            [{'path': ['scanner', 'bucketTimezone'], 'value': 1, 'extra': True}],
        ]
        for paths in cases:
            with self.subTest(paths=paths):
                self.declare(paths)
                self.assert_refused_untouched()

    def test_refuses_a_path_whose_first_key_is_set_flat(self):
        self.seed()
        self.declare(NESTED_PATHS, assign={'scanner': 'x'})
        self.assert_refused_untouched('scanner')

    def test_refuses_a_path_whose_first_key_is_removed(self):
        self.seed()
        self.declare(NESTED_PATHS, remove=['autosubmit'])
        self.assert_refused_untouched('autosubmit')

    def test_refuses_overlapping_paths(self):
        # One path running through another's leaf would either replace a
        # declared scalar with an object or be refused only at run time,
        # depending on the order they happened to be listed in.
        self.seed()
        for paths in ([{'path': ['a'], 'value': 1}, {'path': ['a', 'b'], 'value': 2}],
                      [{'path': ['a', 'b'], 'value': 2}, {'path': ['a'], 'value': 1}],
                      [{'path': ['a', 'b'], 'value': 1}, {'path': ['a', 'b'], 'value': 2}]):
            with self.subTest(paths=paths):
                self.declare(paths)
                self.assert_refused_untouched('["a"')

    def test_refuses_an_unknown_declared_field(self):
        # A misspelt field would otherwise be ignored and its values never
        # asserted, with nothing in the rebuild log to say so.
        self.seed()
        self.declared.write_text(json.dumps({'set': {}, 'setPath': NESTED_PATHS}))
        self.assert_refused_untouched('setPath')

    def test_second_run_does_not_rewrite_the_file(self):
        self.seed()
        self.merge()
        before = self.settings.stat()
        self.merge()
        after = self.settings.stat()
        self.assertEqual(before.st_ino, after.st_ino)
        self.assertEqual(before.st_mtime_ns, after.st_mtime_ns)

    def test_preserves_a_nested_write_that_lands_while_merging(self):
        self.seed()
        original = merger.read_settings
        calls = []

        def read_then_interfere(path):
            current = original(path)
            calls.append(None)
            # The merge loop's first read, after the validation read.
            if len(calls) == 2:
                concurrent = json.loads(json.dumps(current))
                concurrent['scanner']['writtenByTokscale'] = 'keep me'
                path.write_text(json.dumps(concurrent))
            return current

        with mock.patch.object(merger, 'read_settings', read_then_interfere):
            self.merge()
        self.assertEqual(self.read()['scanner'], {
            'opencodeDbPaths': ['x'],
            'bucketTimezone': 'Asia/Seoul',
            'writtenByTokscale': 'keep me',
        })

    def test_does_not_mutate_the_read_document(self):
        # The unchanged check compares the merge against what was read; a merge
        # that edited the read objects in place would always compare equal and
        # never write.
        current = json.loads(json.dumps(NESTED_EXISTING))
        merger.apply(current, {}, [], [(['scanner', 'bucketTimezone'], 'Asia/Seoul')])
        self.assertEqual(current, NESTED_EXISTING)

    def test_flat_declarations_behave_as_before(self):
        # The Gemini declaration carries no setPaths and the Claude global-config
        # one an empty list; both forms must produce the same bytes.
        outputs = []
        for extra in ({}, {'setPaths': []}):
            self.seed(EXISTING)
            self.declared.write_text(json.dumps(dict({'set': DECLARED, 'remove': ['numStartups']}, **extra)))
            self.merge()
            outputs.append(self.settings.read_bytes())
        self.assertEqual(outputs[0], outputs[1])
        result = json.loads(outputs[0])
        self.assertEqual(result, dict({k: v for k, v in EXISTING.items() if k != 'numStartups'}, **DECLARED))

    def test_process_merges_nested_paths(self):
        self.seed()
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--label', 'Tokscale',
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.read()['scanner']['bucketTimezone'], 'Asia/Seoul')

    def test_process_reports_a_non_object_intermediate(self):
        self.seed(dict(NESTED_EXISTING, scanner='flat'))
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--label', 'Tokscale',
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Tokscale settings merge failed', result.stderr)
        self.assertIn('scanner', result.stderr)


# A hooks.json-shaped file maps a hook name to its events. Another writer
# owns `foreign-status` and rewrites it at run time; the declaration owns
# `repo-owned`, seeded here with a stale value so a merger that skipped the
# key could not match by accident.
OWNED = {
    'repo-owned': {
        'enabled': True,
        'SessionStart': [{'type': 'command', 'command': '/nix/store/new --harness antigravity', 'timeout': 10}],
    },
}

OWNED_EXISTING = {
    'foreign-status': {
        'enabled': True,
        'PreInvocation': [{'type': 'command', 'command': 'foreign-hook pre', 'timeout': 10}],
        'Stop': [{'type': 'command', 'command': 'foreign-hook stop', 'timeout': 10}],
    },
    'repo-owned': {
        'enabled': False,
        'SessionStart': [{'type': 'command', 'command': '/nix/store/old', 'timeout': 99}],
        'Stop': [{'type': 'command', 'command': 'stale', 'timeout': 1}],
    },
}


class OwnedKeyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings = Path(self.tmp.name) / 'home/.gemini/config/hooks.json'
        self.declared = Path(self.tmp.name) / 'declared.json'
        self.declare()

    def declare(self, own=None, **fields):
        document = {'own': OWNED if own is None else own}
        document.update(fields)
        self.declared.write_text(json.dumps(document))

    def seed(self, data=None):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(json.dumps(data if data is not None else OWNED_EXISTING, indent=2))
        self.settings.chmod(0o600)

    def merge(self):
        merger.merge(self.settings, self.declared)

    def read(self):
        return json.loads(self.settings.read_text())

    def assert_refused_untouched(self, *needles):
        before = self.settings.read_bytes()
        with self.assertRaises(ValueError) as raised:
            self.merge()
        self.assertEqual(self.settings.read_bytes(), before)
        for needle in needles:
            self.assertIn(needle, str(raised.exception))

    def test_owned_key_is_replaced_whole_and_other_keys_survive(self):
        self.seed()
        self.merge()
        result = self.read()
        self.assertEqual(result['repo-owned'], OWNED['repo-owned'])
        self.assertEqual(result['foreign-status'], OWNED_EXISTING['foreign-status'])
        self.assertEqual(sorted(result), ['foreign-status', 'repo-owned'])

    def test_creates_the_file_with_only_the_owned_key(self):
        self.merge()
        self.assertEqual(self.read(), OWNED)

    def test_second_run_does_not_rewrite_the_file(self):
        self.seed()
        self.merge()
        before = os.stat(self.settings)
        self.merge()
        after = os.stat(self.settings)
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))

    def test_owned_value_is_not_aliased_to_the_declaration(self):
        assign, retire, paths, owned = merger.declaration(self.declared)
        merged = merger.apply({}, assign, retire, paths, owned)
        merged['repo-owned']['enabled'] = False
        self.assertTrue(owned['repo-owned']['enabled'])

    def test_refuses_a_key_both_owned_and_set(self):
        self.seed()
        self.declare(set={'repo-owned': 'flat'})
        self.assert_refused_untouched('repo-owned')

    def test_refuses_a_key_both_owned_and_removed(self):
        self.seed()
        self.declare(remove=['repo-owned'])
        self.assert_refused_untouched('repo-owned')

    def test_refuses_a_path_through_an_owned_key(self):
        self.seed()
        self.declare(setPaths=[{'path': ['repo-owned', 'enabled'], 'value': True}])
        self.assert_refused_untouched('repo-owned')

    def test_refuses_an_own_field_that_is_not_an_object(self):
        self.seed()
        self.declare(own=['repo-owned'])
        self.assert_refused_untouched('own')

    def test_process_merges_owned_keys(self):
        self.seed()
        result = subprocess.run(
            [sys.executable, str(SCRIPT), '--label', 'Antigravity hooks',
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.read()['repo-owned'], OWNED['repo-owned'])
        self.assertEqual(self.read()['foreign-status'], OWNED_EXISTING['foreign-status'])


# Codex keeps config.toml, which it and `codex plugin add` both rewrite, and
# the user edits by hand.  Every declared key starts at the opposite value, and
# the comments and tables the declaration does not name are the bytes a
# re-serializing merger would lose.
TOML_EXISTING = '''\
# Written by hand; keep this comment.
model = "gpt-5.1-codex" # the user's model
check_for_update_on_startup = true # turned back on by hand

[features]
in_app_updates = true
memories = true
web_search = true # unowned sibling

# Installed by codex plugin add.
[plugins."x"]
enabled = true

[marketplaces.y]
source = "https://example.invalid/y.git"

[projects."/home/h82/src"]
trust_level = "trusted"
'''

TOML_DECLARED = {
    'set': {'check_for_update_on_startup': False},
    'setPaths': [
        {'path': ['features', 'in_app_updates'], 'value': False},
        {'path': ['features', 'daemon_auto_start'], 'value': False},
        {'path': ['features', 'memories'], 'value': False},
    ],
}

TOML_MERGED = {
    'check_for_update_on_startup': False,
    'features': {'in_app_updates': False, 'daemon_auto_start': False, 'memories': False},
}


class TomlTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.settings = Path(self.tmp.name) / 'home/.codex/config.toml'
        self.declared = Path(self.tmp.name) / 'declared.json'
        self.declare(TOML_DECLARED)

    def declare(self, document):
        self.declared.write_text(json.dumps(document))

    def seed(self, text=TOML_EXISTING):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(text)
        self.settings.chmod(0o600)

    def merge(self):
        merger.merge(self.settings, self.declared, fmt='toml')

    def read(self):
        return tomlkit.parse(self.settings.read_text()).unwrap()

    def run_script(self):
        return subprocess.run(
            [sys.executable, str(SCRIPT), '--format', 'toml', '--label', 'Codex',
             '--settings', str(self.settings), '--declared', str(self.declared)],
            capture_output=True, text=True)

    def test_declared_keys_reassert_and_user_text_survives(self):
        self.seed()
        self.merge()
        result = self.read()
        self.assertFalse(result['check_for_update_on_startup'])
        self.assertEqual(result['features'], {
            'in_app_updates': False, 'memories': False, 'daemon_auto_start': False, 'web_search': True})
        self.assertEqual(result['model'], 'gpt-5.1-codex')
        text = self.settings.read_text()
        # tomlkit files a comment above a table header under the table before
        # it, so a leaf added to [features] lands after that comment.  Its
        # bytes survive; only its neighbour changes, and only on the run that
        # adds the leaf.
        for unowned in [
            '# Written by hand; keep this comment.\n',
            'model = "gpt-5.1-codex" # the user\'s model\n',
            'check_for_update_on_startup = false # turned back on by hand\n',
            'web_search = true # unowned sibling\n',
            '# Installed by codex plugin add.\n',
            '[plugins."x"]\nenabled = true\n',
            '[marketplaces.y]\nsource = "https://example.invalid/y.git"\n',
            '[projects."/home/h82/src"]\ntrust_level = "trusted"\n',
        ]:
            self.assertIn(unowned, text)

    def test_creates_the_file_with_only_the_declared_keys(self):
        self.merge()
        self.assertEqual(self.read(), TOML_MERGED)
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o600)

    def test_process_refuses_malformed_toml_and_names_the_file(self):
        self.seed('model = "unterminated\n')
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn('Codex settings merge failed', result.stderr)
        self.assertIn(str(self.settings), result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(self.settings.read_text(), 'model = "unterminated\n')

    def test_refuses_null_before_touching_the_file(self):
        # TOML has no null, so a declared null cannot be written; refusing it
        # during validation keeps the refusal from leaving a half-made file.
        self.seed()
        self.settings.parent.chmod(0o755)
        for document in (
            {'set': {'check_for_update_on_startup': None}},
            {'setPaths': [{'path': ['features', 'memories'], 'value': None}]},
            {'own': {'mcp_servers': {'x': {'command': None}}}},
        ):
            with self.subTest(document=document):
                self.declare(document)
                with self.assertRaises(ValueError) as raised:
                    self.merge()
                self.assertIn('null', str(raised.exception))
                self.assertEqual(self.settings.read_text(), TOML_EXISTING)
                self.assertEqual(self.settings.parent.stat().st_mode & 0o777, 0o755)

    def test_null_stays_allowed_in_json(self):
        self.declare({'set': {'model': None}})
        merger.merge(self.settings.with_suffix('.json'), self.declared)
        self.assertEqual(json.loads(self.settings.with_suffix('.json').read_text()), {'model': None})

    def test_remove_drops_a_top_level_key_and_keeps_sibling_tables(self):
        self.seed()
        self.declare(dict(TOML_DECLARED, remove=['model']))
        self.merge()
        result = self.read()
        self.assertNotIn('model', result)
        self.assertEqual(result['plugins'], {'x': {'enabled': True}})
        self.assertEqual(result['marketplaces'], {'y': {'source': 'https://example.invalid/y.git'}})
        self.assertEqual(result['projects'], {'/home/h82/src': {'trust_level': 'trusted'}})

    def test_second_run_does_not_rewrite_the_file(self):
        self.seed()
        self.merge()
        before = self.settings.stat()
        self.merge()
        after = self.settings.stat()
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))

    def test_does_not_mutate_the_read_document(self):
        current = tomlkit.parse(TOML_EXISTING)
        assign, retire, paths, owned = merger.declaration(self.declared, fmt='toml')
        merger.apply(current, assign, retire, paths, owned)
        self.assertEqual(tomlkit.dumps(current), TOML_EXISTING)

    def test_process_merges_toml(self):
        self.seed()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.read()['features']['daemon_auto_start'], False)
        self.assertIn('# Written by hand; keep this comment.\n', self.settings.read_text())


if __name__ == '__main__':
    unittest.main()
