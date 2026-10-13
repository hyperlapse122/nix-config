"""Drive antigravity-cli-release against fake feed fixtures.

The script's network calls go through an overridable command, so these tests
feed it fixture bodies and record which URLs it asked for.
"""

import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/antigravity-cli-release"

BASE = "https://storage.googleapis.com/antigravity-public/antigravity-cli"
X64_HEX = "a1" * 64
ARM_HEX = "b2" * 64
DARWIN_HEX = "c3" * 64
URLS = {
    "linux-x64": f"{BASE}/1.3.4-111/linux-x64/cli_linux_x64.tar.gz",
    "linux-arm": f"{BASE}/1.3.4-111/linux-arm/cli_linux_arm64.tar.gz",
    "darwin-arm": f"{BASE}/1.3.4-111/darwin-arm/cli_mac_arm64.tar.gz",
}


def manifest(version="1.3.4", missing=None, digests=None, urls=None):
    hexes = {"linux-x64": X64_HEX, "linux-arm": ARM_HEX, "darwin-arm": DARWIN_HEX}
    platforms = {
        "linux-musl-x64": {"url": f"{BASE}/x/musl.tar.gz", "sha512": "d4" * 64},
        "windows-x64": {"url": f"{BASE}/x/win.zip", "sha512": "e5" * 64},
    }
    for key, url in URLS.items():
        platforms[key] = {
            "url": (urls or {}).get(key, url),
            "sha512": (digests or {}).get(key, hexes[key]),
        }
    if missing:
        del platforms[missing]
    return json.dumps({"version": version, "platforms": platforms})


def sri(hex_digest):
    return "sha512-" + base64.b64encode(bytes.fromhex(hex_digest)).decode("ascii")


FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
url = sys.argv[1]
with open(os.environ['FAKE_LOG'], 'a') as log:
    log.write(url + '\\n')
if url.endswith('/latest'):
    sys.stdout.write(os.environ['FAKE_LATEST'])
elif url.endswith('/manifest.json'):
    sys.stdout.write(os.environ['FAKE_MANIFEST'])
else:
    sys.exit(22)
"""


class AntigravityCliReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.log = root / "fetch.log"
        self.output = root / "antigravity-cli-release.json"

    def run_release(self, latest="1.3.4\n", body=None, extra_args=None):
        env = dict(os.environ)
        env["AGY_RELEASE_FETCH"] = f"{sys.executable} {self.fetch}"
        env["FAKE_LOG"] = str(self.log)
        env["FAKE_LATEST"] = latest
        env["FAKE_MANIFEST"] = body if body is not None else manifest()
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["-o", str(self.output)])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def fetched(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def write_pin(self, version):
        self.output.write_text(json.dumps({"version": version}) + "\n")

    def assert_refused_unchanged(self, result, needle, before=None):
        self.assertEqual(result.returncode, 1)
        self.assertIn("antigravity-cli-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        if before is None:
            self.assertFalse(self.output.exists())
        else:
            self.assertEqual(self.output.read_bytes(), before)

    def test_writes_the_three_systems_when_newer(self):
        self.write_pin("1.3.3")
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        text = self.output.read_text()
        self.assertTrue(text.endswith("}\n"))
        self.assertEqual(
            json.loads(text),
            {
                "version": "1.3.4",
                "platforms": {
                    "x86_64-linux": {
                        "url": URLS["linux-x64"],
                        "sha512": X64_HEX,
                        "hash": sri(X64_HEX),
                    },
                    "aarch64-linux": {
                        "url": URLS["linux-arm"],
                        "sha512": ARM_HEX,
                        "hash": sri(ARM_HEX),
                    },
                    "aarch64-darwin": {
                        "url": URLS["darwin-arm"],
                        "sha512": DARWIN_HEX,
                        "hash": sri(DARWIN_HEX),
                    },
                },
            },
        )

    def test_missing_pin_is_no_current_version(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.3.4")

    def test_same_version_skips_the_manifest_fetch(self):
        self.write_pin("1.3.4")
        before = self.output.read_bytes()
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(self.fetched(), [f"{BASE}/latest"])

    def test_refuses_an_older_latest_without_writing(self):
        self.write_pin("1.4.0")
        before = self.output.read_bytes()
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_numeric_version_comparison_beats_lexical(self):
        self.write_pin("1.3.9")
        result = self.run_release(latest="1.3.10", body=manifest("1.3.10"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.3.10")

    def test_missing_platform_fails_and_keeps_the_pin(self):
        for missing in URLS:
            with self.subTest(missing=missing):
                self.write_pin("1.3.3")
                before = self.output.read_bytes()
                result = self.run_release(body=manifest(missing=missing))
                self.assert_refused_unchanged(result, missing, before)

    def test_malformed_digest_fails(self):
        for digest in ["abc123", "A1" * 64, "a1" * 63, "zz" * 64]:
            with self.subTest(digest=digest):
                result = self.run_release(body=manifest(digests={"linux-arm": digest}))
                self.assert_refused_unchanged(result, "sha512")

    def test_url_outside_the_feed_fails(self):
        for url in ["http://storage.googleapis.com/antigravity-public/antigravity-cli/x.tgz",
                    "https://example.com/antigravity-cli/x.tgz"]:
            with self.subTest(url=url):
                result = self.run_release(body=manifest(urls={"darwin-arm": url}))
                self.assert_refused_unchanged(result, "url")

    def test_non_numeric_latest_fails(self):
        result = self.run_release(latest="<html>oops</html>")
        self.assert_refused_unchanged(result, "version")
        self.assertEqual(self.fetched(), [f"{BASE}/latest"])

    def test_dry_run_prints_the_pin_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout)["platforms"]["aarch64-darwin"]["hash"],
            sri(DARWIN_HEX),
        )
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
