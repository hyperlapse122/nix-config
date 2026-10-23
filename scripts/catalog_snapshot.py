"""What synthetic-models-watch and openrouter-catalog-snapshot share.

Each script keeps its own row validation, defaults, retries, and rule for a
missing key; this module holds the JSON I/O, the snapshot write, and the
fetch that sends a key only as a bearer header on the command's stdin.
"""

import json
import os
import shlex
import subprocess

DEFAULT_FETCH = "curl -sSfL --max-time 60"


class Failure(Exception):
    """A refusal that should stop the run with a readable message."""


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def is_strings(value):
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def read_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        raise Failure(f"cannot read {path}: {exc}") from None


def write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def write_if_changed(path, text):
    try:
        with open(path, "r", encoding="utf-8") as f:
            if f.read() == text:
                return
    except FileNotFoundError:
        pass
    write(path, text)


def command_from(variable, default):
    command = shlex.split(os.environ.get(variable, default))
    if not command:
        raise Failure(f"{variable} is empty")
    return command


def child_env(key_variable):
    """The environment for subprocesses, without the API key."""
    env = dict(os.environ)
    env.pop(key_variable, None)
    return env


def run_fetch(command, url, key, key_variable):
    """Run the fetch command once; a non-empty key goes only on its stdin, never in its argv."""
    return subprocess.run(
        command + (["-H", "@-"] if key else []) + [url],
        input=f"Authorization: Bearer {key}\n" if key else "",
        capture_output=True,
        text=True,
        env=child_env(key_variable),
    )
