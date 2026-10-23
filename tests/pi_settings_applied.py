"""Checks that a settings file holds every value a declared document sets.

Usage: pi_settings_applied.py DECLARED SETTINGS

DECLARED is the document an activation step hands the merger and SETTINGS the
file that step wrote. Every `set` key and every `setPaths` leaf must hold its
declared value, and a document that sets nothing fails, so an activation that
writes nothing cannot pass. Prints one line per failure and exits 1 when there
is any.
"""
import json
import sys

declared_path, settings_path = sys.argv[1:3]

with open(declared_path) as handle:
    declared = json.load(handle)
try:
    with open(settings_path) as handle:
        merged = json.load(handle)
except (OSError, ValueError) as exc:
    sys.exit('the activation left no readable settings file: {}'.format(exc))

expected = [([key], value) for key, value in declared.get('set', {}).items()]
expected += [(entry['path'], entry['value']) for entry in declared.get('setPaths', [])]
failures = [] if expected else ['the declared document sets nothing']
for path, value in expected:
    node = merged
    for segment in path:
        node = node.get(segment) if isinstance(node, dict) else None
    if node != value:
        failures.append('{} is {!r}, declared {!r}'.format('.'.join(path), node, value))

for line in failures:
    print(line, file=sys.stderr)
sys.exit(1 if failures else 0)
