"""Check the Antigravity runtime pin against the T3 Code CLI the flake builds.

Usage: t3code-antigravity-pin.py T3_BINARY RELEASE_JSON

T3 Code downloads the Antigravity ACP server itself and verifies the archive
against a table compiled into its CLI: the releaseAssets map in
src/provider/antigravityRelease.ts, which the bundled binary carries as plain
JavaScript text. The repository pins the same runtime under the `antigravity`
key of packages/t3code-release.json so Nix can fetch it ahead of time. When
the two disagree, T3 Code rejects or replaces the runtime Nix provides.

Every pinned system must name the Node platform key T3 Code looks up on that
system, the key must be present in the binary's table, and the version, url,
sha256, archiveBytes, executable, and harness must equal that entry. The pin's `hash` is what the Nix fetch uses, so it
must also be the SRI form of the pinned sha256. A binary without a parseable
table, or a pin with no entry compared, fails rather than passing vacuously.
"""

import base64
import json
import re
import sys

VERSION_RE = re.compile(rb'ANTIGRAVITY_RELEASE_VERSION\s*=\s*"([^"]*)"')
# The bundler rewrites `const releaseAssets = new Map([...])` into a hoisted
# `var` plus an assignment, so match the assignment alone.
TABLE_RE = re.compile(
    rb"releaseAssets\s*=\s*(?:/\*.*?\*/\s*)?new Map\((\[.*?\])\)", re.DOTALL
)
# T3 Code looks the table up by `${process.platform}-${process.arch}`.
NODE_PLATFORMS = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "aarch64-darwin": "darwin-arm64",
}
FIELDS = (
    ("version",),
    ("url",),
    ("sha256",),
    ("archiveBytes",),
    ("executable", "name"),
    ("executable", "bytes"),
    ("harness", "name"),
    ("harness", "bytes"),
)


def js_to_json(text, version):
    """Turn the bundled object literal into JSON, resolving the version name."""
    text = re.sub(r":\s*ANTIGRAVITY_RELEASE_VERSION\b", ": " + json.dumps(version), text)
    text = re.sub(r"([{,]\s*)([A-Za-z_$][\w$]*)\s*:", r'\1"\2":', text)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def release_assets(binary):
    """Return the one releaseAssets table the binary embeds, or an error."""
    versions = {m.group(1).decode() for m in VERSION_RE.finditer(binary)}
    if len(versions) != 1:
        return None, f"expected one ANTIGRAVITY_RELEASE_VERSION, found {sorted(versions)}"
    (version,) = versions
    tables = []
    for match in TABLE_RE.finditer(binary):
        try:
            tables.append(dict(js_to_json(match.group(1).decode(), version)))
        except (UnicodeDecodeError, ValueError, TypeError):
            continue
    if not tables:
        return None, "no parseable releaseAssets table in the T3 Code binary"
    if any(table != tables[0] for table in tables):
        return None, "the T3 Code binary embeds releaseAssets tables that differ"
    return tables[0], None


def field(entry, path):
    for key in path:
        entry = entry.get(key) if isinstance(entry, dict) else None
    return entry


def sri(sha256):
    return "sha256-" + base64.b64encode(bytes.fromhex(sha256)).decode()


def main(binary_path, release_path):
    with open(binary_path, "rb") as f:
        assets, error = release_assets(f.read())
    with open(release_path, encoding="utf-8") as f:
        pins = json.load(f).get("antigravity", {})
    if error:
        print(f"t3code-antigravity-pin: {error}", file=sys.stderr)
        return 1

    compared = []
    failures = []
    for system, pin in sorted(pins.items()):
        platform = NODE_PLATFORMS.get(system)
        if pin.get("platform") != platform:
            failures.append(f"{system} ({platform}): platform is {pin.get('platform')!r}")
        try:
            hash_ok = pin.get("hash") == sri(pin.get("sha256", ""))
        except ValueError:
            hash_ok = False
        if not hash_ok:
            failures.append(f"{system} ({platform}): hash is not the SRI form of sha256")
        entry = assets.get(platform)
        if entry is None:
            failures.append(f"{system} ({platform}): platform not in the binary's releaseAssets")
            continue
        compared.append(f"{system} ({platform})")
        for path in FIELDS:
            if field(pin, path) != field(entry, path):
                failures.append(f"{system} ({platform}): {'.'.join(path)} differs from the binary")

    if not compared:
        failures.append("no pinned Antigravity entry was compared")
    for failure in failures:
        print(f"t3code-antigravity-pin: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(f"matches the T3 Code binary: {len(compared)} entries, {', '.join(compared)}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
