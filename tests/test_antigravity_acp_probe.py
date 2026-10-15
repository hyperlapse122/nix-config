"""Unit tests for scripts/antigravity-acp-probe's rule verdicts and cleanup.

The probe itself needs a signed-in Antigravity instance home and the network,
so no check runs it. These tests cover the parts that need neither: how the
answer's rule sections become verdicts, and how the global rule file the probe
plants in the instance home is removed again, including after a failed run.
"""

import importlib.machinery
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parent.parent / 'scripts' / 'antigravity-acp-probe'
loader = importlib.machinery.SourceFileLoader('antigravity_acp_probe', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
probe = importlib.util.module_from_spec(spec)
loader.exec_module(probe)

CONTROL = 'demo-skill'
DESCRIPTION = 'turns a long enough description into a control the probe can match'
WORKSPACE_MARKER = 'PROBE-WORKSPACE-RULE-aaaa'
GLOBAL_MARKER = 'PROBE-GLOBAL-RULE-bbbb'


def answer(workspace_rule='NONE', global_rule='NONE', control=DESCRIPTION):
    return '\n'.join([
        'SKILLS: {}'.format(CONTROL),
        'CONTROL: {}'.format(control),
        'FINGERPRINT: NONE',
        'MARKER: NONE',
        'WORKSPACE_RULE: {}'.format(workspace_rule),
        'GLOBAL_RULE: {}'.format(global_rule),
        'MEMORIES: NONE',
    ])


class VerdictTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name)
        self.rules = (
            probe.RuleProbe('workspace rule', 'WORKSPACE_RULE', WORKSPACE_MARKER, Path('.agents/rules/r.md')),
            probe.RuleProbe('global rule', 'GLOBAL_RULE', GLOBAL_MARKER, self.home / 'config/rules/r.md'),
        )

    def verdicts(self, text, stop_reason='end_turn', tool_calls=0):
        lines = probe.verdicts(self.home, {CONTROL: DESCRIPTION}, CONTROL, text, 'PROBE-MARKER-x',
                               self.rules, stop_reason, tool_calls)
        return {line.split(':', 1)[0]: line.split(':', 1)[1].strip() for line in lines}

    def test_a_returned_marker_is_loaded(self):
        result = self.verdicts(answer(workspace_rule=WORKSPACE_MARKER, global_rule=GLOBAL_MARKER))
        self.assertTrue(result['workspace rule'].startswith('loaded'))
        self.assertTrue(result['global rule'].startswith('loaded'))

    def test_none_with_the_control_back_is_not_loaded(self):
        result = self.verdicts(answer())
        self.assertTrue(result['workspace rule'].startswith('not loaded'))
        self.assertTrue(result['global rule'].startswith('not loaded'))

    def test_none_without_the_control_is_undetermined(self):
        result = self.verdicts(answer(control='NONE'))
        self.assertTrue(result['workspace rule'].startswith('undetermined'))
        self.assertTrue(result['global rule'].startswith('undetermined'))

    def test_a_wrong_marker_is_undetermined(self):
        result = self.verdicts(answer(global_rule='PROBE-GLOBAL-RULE-other'))
        self.assertTrue(result['global rule'].startswith('undetermined'))

    def test_tool_calls_make_every_rule_undetermined(self):
        result = self.verdicts(answer(workspace_rule=WORKSPACE_MARKER, global_rule=GLOBAL_MARKER), tool_calls=1)
        self.assertTrue(result['workspace rule'].startswith('undetermined'))
        self.assertTrue(result['global rule'].startswith('undetermined'))

    def test_a_missing_rule_heading_is_undetermined(self):
        text = answer().replace('GLOBAL_RULE: NONE\n', '')
        self.assertTrue(self.verdicts(text)['global rule'].startswith('undetermined'))


class GlobalRuleCleanupTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name)
        self.rule = probe.RuleProbe('global rule', 'GLOBAL_RULE', GLOBAL_MARKER,
                                    self.home / 'config' / 'rules' / 'antigravity-acp-probe-1234.md')
        self.stderr = io.StringIO()
        patcher = mock.patch.object(sys, 'stderr', self.stderr)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_removes_the_file_and_every_directory_it_created(self):
        created = []
        probe.plant_global_rule(self.rule, created)
        self.assertIn(GLOBAL_MARKER, self.rule.path.read_text())
        self.assertEqual(created, [self.home / 'config' / 'rules', self.home / 'config'])
        probe.remove_global_rule(self.rule, created)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_keeps_directories_that_existed_and_files_beside_it(self):
        (self.home / 'config' / 'rules').mkdir(parents=True)
        mine = self.home / 'config' / 'rules' / 'mine.md'
        mine.write_text('user rule')
        created = []
        probe.plant_global_rule(self.rule, created)
        self.assertEqual(created, [])
        probe.remove_global_rule(self.rule, created)
        self.assertEqual(list((self.home / 'config' / 'rules').iterdir()), [mine])

    def test_keeps_a_created_directory_the_runtime_wrote_into(self):
        created = []
        probe.plant_global_rule(self.rule, created)
        other = self.home / 'config' / 'settings.json'
        other.write_text('{}')
        probe.remove_global_rule(self.rule, created)
        self.assertFalse((self.home / 'config' / 'rules').exists())
        self.assertTrue(other.exists())

    def test_a_cleanup_error_is_reported_not_raised(self):
        created = []
        probe.plant_global_rule(self.rule, created)
        with mock.patch.object(Path, 'unlink', side_effect=PermissionError('denied')):
            probe.remove_global_rule(self.rule, created)
        self.assertIn('could not remove', self.stderr.getvalue())

    def test_a_partial_plant_still_names_its_directories(self):
        created = []
        with mock.patch.object(Path, 'write_text', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                probe.plant_global_rule(self.rule, created)
        probe.remove_global_rule(self.rule, created)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_removes_only_stale_probe_rules(self):
        rules = self.home / 'config' / 'rules'
        rules.mkdir(parents=True)
        stale = rules / 'antigravity-acp-probe-dead.md'
        stale.write_text('The rule marker for the instance home is PROBE-GLOBAL-RULE-0000.')
        named_alike = rules / 'antigravity-acp-probe-user.md'
        named_alike.write_text('a user file that happens to share the prefix')
        user = rules / 'mine.md'
        user.write_text('PROBE-GLOBAL-RULE- mentioned by the user')
        self.assertEqual(probe.remove_stale_global_rules(rules), [stale])
        self.assertEqual(sorted(rules.iterdir()), sorted([named_alike, user]))

    def test_stale_cleanup_without_a_rules_directory_is_a_no_op(self):
        self.assertEqual(probe.remove_stale_global_rules(self.home / 'config' / 'rules'), [])


if __name__ == '__main__':
    unittest.main()
