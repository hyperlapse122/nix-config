"""Add rendered instruction text to a declared-settings document at build time.

    declare.py BASE OUT [--leaf PATH-JSON ENCODING FILE]...

BASE is the declaration Nix rendered with builtins.toJSON. Each --leaf appends
a setPaths entry whose value comes from FILE, a rendered instruction part in
the store, so evaluation never reads a derivation's output.

ENCODING is `text` for the file's contents as they are, or `codex-launch` for
a T3 Code launch argument that sets Codex's developer_instructions: a TOML
basic string inside one single-quoted word, which T3 Code's tokenizer ends at
the first bare `'`. TOML basic strings have no `\\'`, so `'` takes a `\\u0027`
escape, and the word holds no bare `'`.
"""

import json
import sys


def toml_basic(text):
    # A JSON string is a TOML basic string with the same escapes, except that
    # TOML forbids a raw DEL. `'` is escaped too, for the tokenizer.
    return json.dumps(text, ensure_ascii=False).replace("'", '\\u0027').replace('\x7f', '\\u007f')


ENCODINGS = {
    'text': lambda text: text,
    'codex-launch': lambda text: "-c 'developer_instructions={}'".format(toml_basic(text)),
}


def main(argv):
    base, out, rest = argv[0], argv[1], argv[2:]
    with open(base, encoding='utf-8') as handle:
        declared = json.load(handle)
    while rest:
        flag, path, encoding, source, rest = rest[0], rest[1], rest[2], rest[3], rest[4:]
        if flag != '--leaf':
            raise SystemExit('declare.py: expected --leaf, got {}'.format(flag))
        with open(source, encoding='utf-8') as handle:
            text = handle.read()
        declared.setdefault('setPaths', []).append({'path': json.loads(path), 'value': ENCODINGS[encoding](text)})
    with open(out, 'w', encoding='utf-8') as handle:
        json.dump(declared, handle, separators=(',', ':'), ensure_ascii=False)


if __name__ == '__main__':
    main(sys.argv[1:])
