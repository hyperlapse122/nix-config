"""Applies the declared Pi models.json to an empty home and has Pi load it.

Usage: pi_models_load.py PI MERGER DECLARED WORKDIR

PI is the packaged pi wrapper, MERGER the packaged agent-settings, and
DECLARED the models.json declaration home.activation hands the merger. Pi runs
offline with a throwaway HOME and fake keys. Pi 1.4.0 drops every custom
model when one field of models.json is invalid and still exits 0, so the run
fails when Pi reports any models.json error or leaves out a model the
declaration names. A copy of the merged file with one maxTokens set to null
must fail the same test, so a change in how Pi reports the error cannot turn
the check green. Prints one line per failure and exits 1 when there is any.
"""
import itertools
import json
import os
import subprocess
import sys

pi, merger, declared_path, workdir = sys.argv[1:5]

failures = []
homes = itertools.count()

with open(declared_path) as handle:
    declared = json.load(handle)

# provider -> the model IDs the declaration names for it.
expected = {}
for owned in declared.get('ownEntries', []):
    provider = owned['path'][1]
    entries = owned['entries']
    ids = [entry[owned['key']] for entry in entries] if 'key' in owned else list(entries)
    expected.setdefault(provider, set()).update(ids)


def problems(models):
    """What is wrong with Pi's view of a home holding `models` as models.json."""
    home = os.path.join(workdir, 'home-{}'.format(next(homes)))
    agent = os.path.join(home, '.pi', 'agent')
    os.makedirs(agent)
    with open(os.path.join(agent, 'models.json'), 'w') as handle:
        json.dump(models, handle)
    result = subprocess.run(
        [pi, '--list-models'],
        env={
            'HOME': home,
            'PATH': os.environ['PATH'],
            'PI_OFFLINE': '1',
            'OPENROUTER_API_KEY': 'sk-fake-openrouter',
            'SYNTHETIC_API_KEY': 'sk-fake-synthetic',
        },
        capture_output=True, text=True,
    )
    found = []
    if result.returncode != 0:
        found.append('pi --list-models exited {}: {}'.format(result.returncode, result.stderr.strip()))
    if 'models.json' in result.stdout + result.stderr:
        found.append('pi reported a models.json problem: {}'.format(result.stderr.strip()))
    listed = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            listed.setdefault(fields[0], set()).add(fields[1])
    for provider in ('synthetic', 'openrouter'):
        if not expected.get(provider):
            found.append('the declaration names no {} model'.format(provider))
        missing = sorted(expected.get(provider, set()) - listed.get(provider, set()))
        if missing:
            found.append('pi does not list {} {} model(s), such as {}'.format(len(missing), provider, missing[:3]))
    return found


os.makedirs(workdir, exist_ok=True)
target = os.path.join(workdir, 'models.json')
merge = subprocess.run(
    [merger, '--label', 'Pi models', '--settings', target, '--declared', declared_path,
     '--ledger', os.path.join(workdir, 'ledger.json')],
    env={}, capture_output=True, text=True,
)
if merge.returncode != 0:
    failures.append('the merger refused the declaration: {}'.format(merge.stderr.strip()))
else:
    with open(target) as handle:
        merged = json.load(handle)
    failures.extend(problems(merged))

    poisoned = json.loads(json.dumps(merged))
    poisoned['providers']['synthetic']['models'][0]['maxTokens'] = None
    if not problems(poisoned):
        failures.append('a models.json holding maxTokens null passed; the check cannot see a rejected file')

for message in failures:
    print(message)
sys.exit(1 if failures else 0)
