"""Reads the Claude instructions directory out of a declared-settings file.

    agent-instruction-channels.py DECLARED

Requires the Claude instance's launch arguments to be exactly
`--add-dir <dir>`, and its environment to upsert
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1, and prints the directory.

Every mismatch exits 1 with a message, so the check names what broke.
"""

import json
import shlex
import sys


def leaf(declared, path):
    values = [entry['value'] for entry in declared.get('setPaths', []) if entry['path'] == path]
    if len(values) != 1:
        sys.exit('expected exactly one declared {}, found {}'.format('.'.join(path), len(values)))
    return values[0]


def main(declared_path):
    with open(declared_path, encoding='utf-8') as handle:
        declared = json.load(handle)
    words = shlex.split(leaf(declared, ['providerInstances', 'claudeAgent', 'config', 'launchArgs']))
    if len(words) != 2 or words[0] != '--add-dir':
        sys.exit('the Claude launch arguments are not one --add-dir <dir>: {!r}'.format(words))
    upserts = [
        entry['value'] for entry in declared.get('upsertPaths', [])
        if entry['path'] == ['providerInstances', 'claudeAgent', 'environment'] and entry['key'] == 'name'
    ]
    wanted = [value for value in upserts if value.get('name') == 'CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD']
    if len(wanted) != 1 or wanted[0].get('value') != '1':
        sys.exit('the Claude instance environment does not upsert CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1')
    print(words[1])


if __name__ == '__main__':
    main(*sys.argv[1:])
