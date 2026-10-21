"""Check that the Antigravity ACP runtime pin matches between pin files.

Usage: t3code-antigravity-pin.py T3CODE_RELEASE_JSON AGY_ACP_RELEASE_JSON

KTD1: scripts/antigravity-acp-release is the only writer that changes the
Antigravity archive identity, and it writes that identity into
packages/antigravity-acp-release.json and into the antigravity section of
packages/t3code-release.json. This check compares the two pin files with each
other. It does not download archives, and it does not compare either file
with the table embedded in the CLI.

Every system the flake supports must be pinned in both files, and their
platform, version, url, sha256, hash, archiveBytes, executable, and harness
must match. The pin's `hash` must be the SRI form of sha256. Fails closed when
a pin file is missing, when a supported system is missing, when the two files
disagree, or when no comparison was executed.
"""

import base64
import json
import os
import sys

SYSTEMS = (
    "x86_64-linux",
    "aarch64-linux",
    "aarch64-darwin",
)

FIELDS = (
    ("platform",),
    ("version",),
    ("url",),
    ("sha256",),
    ("hash",),
    ("archiveBytes",),
    ("executable", "name"),
    ("executable", "bytes"),
    ("harness", "name"),
    ("harness", "bytes"),
)


def field(entry, path):
    for key in path:
        entry = entry.get(key) if isinstance(entry, dict) else None
    return entry


def sri(sha256):
    return "sha256-" + base64.b64encode(bytes.fromhex(sha256)).decode("ascii")


def load_pins(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"pin file {path} does not exist")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path} does not contain a JSON object")
    if "antigravity" in data:
        return data.get("antigravity", {})
    if "platforms" in data:
        return data.get("platforms", {})
    return {}


def main(file_a, file_b):
    try:
        pins_a = load_pins(file_a)
        pins_b = load_pins(file_b)
    except Exception as exc:
        print(f"t3code-antigravity-pin: {exc}", file=sys.stderr)
        return 1

    compared = []
    failures = []
    all_systems = sorted(set(SYSTEMS) | set(pins_a) | set(pins_b))
    for system in all_systems:
        if system not in SYSTEMS:
            failures.append(f"{system}: unexpected system in pin files")
            continue
        entry_a = pins_a.get(system)
        entry_b = pins_b.get(system)
        if entry_a is None or entry_b is None:
            failures.append(f"{system}: missing from one or both pin files")
            continue

        for p_name, entry in (("first pin", entry_a), ("second pin", entry_b)):
            sha = entry.get("sha256", "")
            expected_hash = ""
            try:
                expected_hash = sri(sha)
            except Exception:
                pass
            if entry.get("hash") != expected_hash:
                failures.append(f"{system} ({p_name}): hash is not the SRI form of sha256")

        for path in FIELDS:
            val_a = field(entry_a, path)
            val_b = field(entry_b, path)
            if val_a != val_b:
                failures.append(
                    f"{system}: {'.'.join(path)} differs between pin files: {val_a!r} != {val_b!r}"
                )

        compared.append(system)

    if not compared:
        failures.append("no pinned Antigravity entry was compared")

    for failure in failures:
        print(f"t3code-antigravity-pin: {failure}", file=sys.stderr)

    if failures:
        return 1

    print(f"matches: {len(compared)} entries, {', '.join(compared)}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
