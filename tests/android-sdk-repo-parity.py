"""Check the Android SDK pin against the repo.json nixpkgs ships.

Usage: android-sdk-repo-parity.py PIN NIXPKGS_REPO_JSON

android-sdk-release converts Google's repository XML with functions vendored
from nixpkgs' androidenv update.rb. Every package the pin carries that
nixpkgs' own repo.json also carries must therefore be identical to it, apart
from the last-available-day stamp update.rb adds to expire old records. A
difference means the vendored conversion drifted from upstream, or one of the
two files was written from a different upstream archive.

A package the pin carries but nixpkgs does not yet list is skipped, since the
pin can track a release before nixpkgs picks it up. The declared build-tools
and platforms stay in nixpkgs' repo.json for years, so at least one package
must be comparable; none would leave the check asserting nothing.
"""

import json
import sys


def main(pin_path, upstream_path):
    with open(pin_path, encoding="utf-8") as f:
        pin = json.load(f)
    with open(upstream_path, encoding="utf-8") as f:
        upstream = json.load(f)

    compared = []
    failures = []
    for name, versions in sorted(pin["packages"].items()):
        for version, entry in sorted(versions.items()):
            theirs = upstream["packages"].get(name, {}).get(version)
            if theirs is None:
                print(f"skip {name} {version}: not in nixpkgs repo.json")
                continue
            theirs = {k: v for k, v in theirs.items() if k != "last-available-day"}
            compared.append(f"{name} {version}")
            if entry != theirs:
                keys = sorted(
                    k
                    for k in entry.keys() | theirs.keys()
                    if entry.get(k) != theirs.get(k)
                )
                failures.append(f"{name} {version} differs in {', '.join(keys)}")

    if not compared:
        failures.append("no pinned package is in nixpkgs repo.json to compare")
    for failure in failures:
        print(f"android-sdk-repo-parity: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(f"matches nixpkgs repo.json: {', '.join(compared)}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
