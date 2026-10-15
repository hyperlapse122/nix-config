"""Splits the declared Codex launch argument with the pinned T3 Code's own tokenizer.

    t3code-codex-launch.py BUNDLE DECLARED RENDERED

BUNDLE is the pinned T3 Code CLI bundle, DECLARED a declared-settings file
holding the providerInstances.codex.config.launchArgs leaf, and RENDERED the
instruction text that leaf must carry. The other checks split the argument
with Python's shlex, which only matches T3 Code's tokenizer by assumption; this
one copies tokenizeCliArgs out of the bundle, runs it under node, and requires
exactly `-c developer_instructions=<TOML string>` whose value is RENDERED.
"""

import json
import subprocess
import sys
import tempfile
import tomllib

START = 'function tokenizeCliArgs(args) {'


def tokenizer(bundle):
    with open(bundle, encoding='utf-8', errors='surrogateescape') as handle:
        lines = handle.read().split('\n')
    starts = [index for index, line in enumerate(lines) if line == START]
    if len(starts) != 1:
        sys.exit('expected one `{}` line in the pinned T3 Code, found {}'.format(START, len(starts)))
    for end in range(starts[0] + 1, len(lines)):
        if lines[end] == '}':
            return '\n'.join(lines[starts[0]:end + 1])
    sys.exit('tokenizeCliArgs in the pinned T3 Code has no closing line')


def main(bundle, declared_path, rendered_path):
    with open(declared_path, encoding='utf-8') as handle:
        declared = json.load(handle)
    values = [entry['value'] for entry in declared.get('setPaths', [])
              if entry['path'] == ['providerInstances', 'codex', 'config', 'launchArgs']]
    if len(values) != 1:
        sys.exit('expected one declared Codex launchArgs, found {}'.format(len(values)))
    with tempfile.NamedTemporaryFile('w', suffix='.js', encoding='utf-8', delete=False) as script:
        script.write(tokenizer(bundle))
        script.write('\nprocess.stdout.write(JSON.stringify(tokenizeCliArgs(require("fs").readFileSync(0, "utf8"))));\n')
    words = json.loads(subprocess.run(['node', script.name], input=values[0], capture_output=True,
                                      text=True, encoding='utf-8', check=True).stdout)
    if len(words) != 2 or words[0] != '-c' or not words[1].startswith('developer_instructions='):
        sys.exit('T3 Code splits the Codex launch arguments into {!r}, not -c developer_instructions=...'.format(
            [word[:40] for word in words[:3]]))
    try:
        text = tomllib.loads('value = ' + words[1].split('=', 1)[1])['value']
    except tomllib.TOMLDecodeError as error:
        sys.exit('the developer_instructions override T3 Code passes is not one TOML string: {}'.format(error))
    with open(rendered_path, encoding='utf-8') as handle:
        if text != handle.read():
            sys.exit('the developer_instructions override T3 Code passes differs from the rendered parts')


if __name__ == '__main__':
    main(*sys.argv[1:])
