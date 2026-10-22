#!/usr/bin/env python3
"""Check the hidden text-generation alias of T3 Code against the OpenCode settings.

Run by tests/t3code-traits.nix with the packaged scripts/agent-settings and the
two declared documents a configuration's activation passes to it:

  t3code-hidden-model.py MERGER T3CODE_DECLARED OPENCODE_DECLARED

home/h82/t3code.nix builds the alias it hides as `synthetic/<id>@<effort>`, and
home/h82/agents/opencode.nix builds the `small_model` key the same way, each
from its own formula. The alias is the entry OpenCode's small_model names, so
the two must stay one string, and it is the model text generation selects on
the Pi instance plus `@` and that selection's `thinking` effort. Then the
real merger runs on the T3 Code document over a settings.json that already
hides another model and an alias of an earlier effort: the other model must
stay hidden, the earlier alias must go, and the current one must be hidden
exactly once, also on a second run.

Every failure is printed, and the exit status is 1 when there is any.
"""
import json
import os
import subprocess
import sys
import tempfile

HIDDEN = ['providerModelPreferences', 'opencode', 'hiddenModels']
OTHER = 'synthetic/hf:other-org/Other-Model'


def load(path):
    with open(path) as handle:
        return json.load(handle)


def get(document, path):
    for key in path:
        if not isinstance(document, dict) or key not in document:
            return None
        document = document[key]
    return document


def main(merger, t3_path, opencode_path):
    problems = []
    t3 = load(t3_path)
    opencode = load(opencode_path)

    entries = [e for e in t3.get('prefixEntries', []) if e.get('path') == HIDDEN]
    if len(entries) != 1:
        return ['the T3 Code declaration holds {} prefixEntries for {}, not 1'.format(
            len(entries), '.'.join(HIDDEN))]
    alias = entries[0].get('value')
    prefix = entries[0].get('prefix')
    small = get(opencode, ['set', 'small_model'])

    if not isinstance(alias, str) or not alias:
        return ['the hidden alias is not a non-empty string: {!r}'.format(alias)]
    if alias != small:
        problems.append('T3 Code hides {!r}, but OpenCode declares small_model {!r}'.format(alias, small))
    if '@' not in alias or prefix != alias[:alias.rindex('@') + 1]:
        problems.append('the hidden alias {!r} does not extend its retire prefix {!r}'.format(alias, prefix))
    selection = get(t3, ['own', 'textGenerationModelSelection'])
    if get(selection, ['instanceId']) != 'pi':
        problems.append('text generation selects instance {!r}, not pi'.format(get(selection, ['instanceId'])))
    thinking = [
        option.get('value') for option in get(selection, ['options']) or []
        if isinstance(option, dict) and option.get('id') == 'thinking'
    ]
    if len(thinking) != 1:
        problems.append('text generation declares {} thinking options, not 1'.format(len(thinking)))
    elif '{}@{}'.format(get(selection, ['model']), thinking[0]) != alias:
        problems.append('T3 Code hides {!r}, but text generation selects {!r} at thinking {!r}'.format(
            alias, get(selection, ['model']), thinking[0]))
    declared_keys = {
        entry['path'][3]
        for entry in opencode.get('setPaths', [])
        if entry.get('path', [])[:3] == ['provider', 'synthetic', 'models'] and len(entry['path']) > 3
    }
    if not alias.startswith('synthetic/') or alias[len('synthetic/'):] not in declared_keys:
        problems.append('OpenCode declares no model entry for the hidden alias {!r}'.format(alias))
    if problems:
        return problems

    base = prefix[:-1]
    efforts = ('high', 'max')
    stale = next(prefix + e for e in efforts if prefix + e != alias)
    seeded = {
        'unrelated': {'kept': True},
        'providerModelPreferences': {'opencode': {'hiddenModels': [OTHER, stale, base]}},
    }
    expected = [OTHER, base, alias]
    with tempfile.TemporaryDirectory() as work:
        target = os.path.join(work, 'settings.json')
        with open(target, 'w') as handle:
            json.dump(seeded, handle)
        os.chmod(target, 0o644)
        for attempt in ('first', 'second'):
            result = subprocess.run(
                [merger, '--label', 't3codeSettings', '--settings', target, '--declared', t3_path],
                env={}, capture_output=True, text=True)
            if result.returncode != 0:
                return problems + ['the merger refused the {} run: {}'.format(attempt, result.stderr.strip())]
            hidden = get(load(target), HIDDEN)
            if hidden != expected:
                problems.append('after the {} merge hiddenModels is {!r}, not {!r}'.format(
                    attempt, hidden, expected))
            if get(load(target), ['unrelated', 'kept']) is not True:
                problems.append('the {} merge dropped a key the declaration does not touch'.format(attempt))
    return problems


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit('usage: t3code-hidden-model.py MERGER T3CODE_DECLARED OPENCODE_DECLARED')
    found = main(*sys.argv[1:])
    for line in found:
        print(line, file=sys.stderr)
    sys.exit(1 if found else 0)
