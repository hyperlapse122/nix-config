"""Reads an instruction channel out of a declared-settings file.

    agent-instruction-channels.py developer DECLARED OUT
    agent-instruction-channels.py codex-launch DECLARED OUT
    agent-instruction-channels.py claude-dir DECLARED

`developer` writes the Codex `developer_instructions` value to OUT.
`codex-launch` splits the T3 Code Codex instance's launch arguments the way a
POSIX shell does, which for single quotes is how T3 Code's tokenizer splits
them, requires exactly `-c developer_instructions=<TOML>`, and writes the
decoded TOML string to OUT. `claude-dir` requires the Claude instance's launch
arguments to be exactly `--add-dir <dir>`, and its environment to upsert
CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1, and prints the directory.

Every mismatch exits 1 with a message, so the check names what broke.
"""

import json
import shlex
import sys
import tomllib


def leaf(declared, path):
    values = [entry['value'] for entry in declared.get('setPaths', []) if entry['path'] == path]
    if len(values) != 1:
        sys.exit('expected exactly one declared {}, found {}'.format('.'.join(path), len(values)))
    return values[0]


def main(mode, declared_path, out=None):
    with open(declared_path) as handle:
        declared = json.load(handle)
    if mode == 'developer':
        text = leaf(declared, ['developer_instructions'])
    elif mode == 'codex-launch':
        words = shlex.split(leaf(declared, ['providerInstances', 'codex', 'config', 'launchArgs']))
        if len(words) != 2 or words[0] != '-c' or not words[1].startswith('developer_instructions='):
            sys.exit('the Codex launch arguments are not one -c developer_instructions=...: {!r}'.format(words[:3]))
        try:
            text = tomllib.loads('value = ' + words[1].split('=', 1)[1])['value']
        except tomllib.TOMLDecodeError as error:
            sys.exit('the Codex developer_instructions override is not one TOML string: {}'.format(error))
        if not isinstance(text, str):
            sys.exit('the Codex developer_instructions override is not a string')
    elif mode == 'claude-dir':
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
        return
    else:
        sys.exit('unknown mode {}'.format(mode))
    with open(out, 'w') as handle:
        handle.write(text)


if __name__ == '__main__':
    main(*sys.argv[1:])
