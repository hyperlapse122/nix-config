"""Add rendered instruction text to a declared-settings document at build time.

    declare.py BASE OUT [--leaf PATH-JSON ENCODING FILE]...

BASE is the declaration Nix rendered with builtins.toJSON. Each --leaf appends
a setPaths entry whose value comes from FILE, a rendered instruction part in
the store, so evaluation never reads a derivation's output.

ENCODING is `text` for the file's contents as they are, or `codex-launch` for
a T3 Code launch argument that sets Codex's developer_instructions: a TOML
basic string inside one single-quoted word, which T3 Code's tokenizer ends at
the first bare `'`. TOML basic strings have no `\\'`, so `'` and every control
character take a `\\uXXXX` escape, and the word holds no bare `'`.
"""

import json
import sys


def toml_basic(text):
    out = []
    for char in text:
        if char == '\\':
            out.append('\\\\')
        elif char == '"':
            out.append('\\"')
        elif char == '\n':
            out.append('\\n')
        elif char == "'" or ord(char) < 0x20 or ord(char) == 0x7f:
            out.append('\\u{:04x}'.format(ord(char)))
        else:
            out.append(char)
    return '"' + ''.join(out) + '"'


ENCODINGS = {
    'text': lambda text: text,
    'codex-launch': lambda text: "-c 'developer_instructions={}'".format(toml_basic(text)),
}


def main(argv):
    base, out, rest = argv[0], argv[1], argv[2:]
    with open(base) as handle:
        declared = json.load(handle)
    while rest:
        flag, path, encoding, source, rest = rest[0], rest[1], rest[2], rest[3], rest[4:]
        if flag != '--leaf':
            raise SystemExit('declare.py: expected --leaf, got {}'.format(flag))
        with open(source) as handle:
            text = handle.read()
        declared.setdefault('setPaths', []).append({'path': json.loads(path), 'value': ENCODINGS[encoding](text)})
    with open(out, 'w') as handle:
        json.dump(declared, handle, separators=(',', ':'), ensure_ascii=False)


if __name__ == '__main__':
    main(sys.argv[1:])
