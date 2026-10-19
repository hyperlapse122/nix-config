"""Drive grok-build-release against stable-channel, header, and prefetch fixtures.

The helper's channel read, its HEAD requests, and its downloads all go through
overridable commands, so these tests feed it fixtures instead of network
calls. The fake prefetch writes a file per URL and reports it as the store
path, so the md5 cross-check reads real bytes.
"""

import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/grok-build-release"

BASE = "https://x.ai/cli"
SYSTEMS = {
    "x86_64-linux": "linux-x86_64",
    "aarch64-linux": "linux-aarch64",
    "aarch64-darwin": "macos-aarch64",
}


def url(version, platform):
    return f"{BASE}/grok-{version}-{platform}"


def content(binary_url):
    return f"grok binary at {binary_url}\n".encode()


def sri(data):
    return "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()


FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
with open(os.environ['FAKE_LOG'], 'a') as f:
    f.write('fetch ' + sys.argv[-1] + '\\n')
sys.stdout.write(os.environ['FAKE_STABLE'])
"""

# Prints the headers curl -sI prints, with the two x-goog-hash lines GCS
# sends, or only the crc32c one for a URL in FAKE_NO_MD5, or fails the way
# curl -f does on a 404.
FAKE_HEAD = """#!/usr/bin/env python3
import base64, hashlib, os, sys
url = sys.argv[-1]
with open(os.environ['FAKE_LOG'], 'a') as f:
    f.write('head ' + url + '\\n')
if url in os.environ.get('FAKE_MISSING', '').split():
    sys.exit(22)
data = ('grok binary at ' + url + '\\n').encode()
digest = base64.b64encode(hashlib.md5(data).digest()).decode()
md5 = '' if url in os.environ.get('FAKE_NO_MD5', '').split() else 'x-goog-hash: md5=%s\\r\\n' % digest
sys.stdout.write('HTTP/2 200 \\r\\ncontent-length: %d\\r\\n'
                 'x-goog-hash: crc32c=cP/tdA==\\r\\n%s\\r\\n' % (len(data), md5))
"""

FAKE_PREFETCH = """#!/usr/bin/env python3
import base64, hashlib, json, os, sys
url = sys.argv[-1]
with open(os.environ['FAKE_LOG'], 'a') as f:
    f.write('prefetch ' + url + '\\n')
data = ('grok binary at ' + url + '\\n').encode()
if url == os.environ.get('FAKE_CORRUPT'):
    data += b'truncated'
path = os.path.join(os.environ['FAKE_STORE'], url.rsplit('/', 1)[-1])
with open(path, 'wb') as f:
    f.write(data)
digest = 'sha256-' + base64.b64encode(hashlib.sha256(data).digest()).decode()
result = {'hash': os.environ.get('FAKE_HASH') or digest, 'storePath': path}
if os.environ.get('FAKE_NO_STORE_PATH'):
    del result['storePath']
print(json.dumps(result))
"""


class GrokBuildReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.stubs = {}
        for name, text in [("fetch", FAKE_FETCH), ("head", FAKE_HEAD), ("prefetch", FAKE_PREFETCH)]:
            path = root / f"fake-{name}"
            path.write_text(text)
            self.stubs[name] = path
        self.store = root / "store"
        self.store.mkdir()
        self.log = root / "calls.log"
        self.output = root / "grok-build-release.json"

    def run_release(
        self,
        stable="1.0.62",
        extra_args=None,
        missing=(),
        corrupt="",
        prefetch_hash="",
        no_md5=(),
        no_store_path=False,
    ):
        env = dict(os.environ)
        env["GROK_BUILD_RELEASE_FETCH"] = f"{sys.executable} {self.stubs['fetch']}"
        env["GROK_BUILD_RELEASE_HEAD"] = f"{sys.executable} {self.stubs['head']}"
        env["GROK_BUILD_RELEASE_PREFETCH"] = f"{sys.executable} {self.stubs['prefetch']}"
        env["FAKE_STABLE"] = stable
        env["FAKE_MISSING"] = " ".join(missing)
        env["FAKE_CORRUPT"] = corrupt
        env["FAKE_HASH"] = prefetch_hash
        env["FAKE_NO_MD5"] = " ".join(no_md5)
        env["FAKE_NO_STORE_PATH"] = "1" if no_store_path else ""
        env["FAKE_STORE"] = str(self.store)
        env["FAKE_LOG"] = str(self.log)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--output", str(self.output)])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def calls(self, kind):
        if not self.log.exists():
            return []
        prefix = kind + " "
        return [line[len(prefix):] for line in self.log.read_text().splitlines() if line.startswith(prefix)]

    def write_pin(self, version):
        self.output.write_text(json.dumps({"version": version, "platforms": {}}, indent=2) + "\n")
        return self.output.read_text()

    def expected_pin(self, version):
        platforms = {}
        for system, platform in SYSTEMS.items():
            binary = url(version, platform)
            platforms[system] = {"url": binary, "hash": sri(content(binary))}
        return json.dumps({"version": version, "platforms": platforms}, indent=2) + "\n"

    def test_a_newer_stable_with_every_platform_writes_three_entries(self):
        self.write_pin("1.0.61")
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), self.expected_pin("1.0.62"))
        self.assertEqual(self.calls("fetch"), [f"{BASE}/stable"])
        self.assertEqual(self.calls("prefetch"), [url("1.0.62", p) for p in SYSTEMS.values()])
        self.assertIn("updated", result.stdout)

    def test_a_missing_pin_file_is_written(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), self.expected_pin("1.0.62"))
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o644)

    def test_a_missing_platform_refuses_and_keeps_the_pin(self):
        for platform in SYSTEMS.values():
            with self.subTest(platform=platform):
                self.log.unlink(missing_ok=True)
                before = self.write_pin("1.0.61")
                result = self.run_release(missing=[url("1.0.62", platform)])
                self.assertEqual(result.returncode, 1)
                self.assertIn("refusing to write an incomplete pin", result.stderr)
                self.assertEqual(self.output.read_text(), before)
                self.assertEqual(self.calls("prefetch"), [])

    def test_a_stable_not_newer_than_the_pin_downloads_nothing(self):
        for pinned in ["1.0.62", "1.0.63", "1.1.0"]:
            with self.subTest(pinned=pinned):
                self.log.unlink(missing_ok=True)
                before = self.write_pin(pinned)
                result = self.run_release()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("already up to date", result.stdout)
                self.assertEqual(self.output.read_text(), before)
                self.assertEqual(self.calls("head"), [])
                self.assertEqual(self.calls("prefetch"), [])

    def test_an_md5_mismatch_fails_and_keeps_the_pin(self):
        for platform in SYSTEMS.values():
            with self.subTest(platform=platform):
                before = self.write_pin("1.0.61")
                result = self.run_release(corrupt=url("1.0.62", platform))
                self.assertEqual(result.returncode, 1)
                self.assertIn("but the host reports", result.stderr)
                self.assertEqual(self.output.read_text(), before)

    def test_a_prefetch_without_a_sha256_sri_fails_and_keeps_the_pin(self):
        before = self.write_pin("1.0.61")
        result = self.run_release(prefetch_hash="sha1-AAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        self.assertEqual(result.returncode, 1)
        self.assertIn("carries no sha256 SRI hash", result.stderr)
        self.assertEqual(self.output.read_text(), before)

    def test_a_head_without_an_md5_refuses_before_any_download(self):
        for platform in SYSTEMS.values():
            with self.subTest(platform=platform):
                self.log.unlink(missing_ok=True)
                before = self.write_pin("1.0.61")
                result = self.run_release(no_md5=[url("1.0.62", platform)])
                self.assertEqual(result.returncode, 1)
                self.assertIn(f"{url('1.0.62', platform)} reports no x-goog-hash md5", result.stderr)
                self.assertEqual(self.output.read_text(), before)
                self.assertEqual(self.calls("prefetch"), [])

    def test_a_prefetch_without_a_store_path_fails_and_keeps_the_pin(self):
        before = self.write_pin("1.0.61")
        result = self.run_release(no_store_path=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("names no store path", result.stderr)
        self.assertEqual(self.output.read_text(), before)

    def test_a_non_numeric_pin_is_treated_as_older_than_the_stable(self):
        # version_tuple cannot order the pin, so the helper resolves the
        # stable release rather than keep an unreadable pin forever.
        for pinned in ["latest", "1.0.62-beta", ""]:
            with self.subTest(pinned=pinned):
                self.log.unlink(missing_ok=True)
                self.write_pin(pinned)
                result = self.run_release()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.output.read_text(), self.expected_pin("1.0.62"))
                self.assertEqual(self.calls("prefetch"), [url("1.0.62", p) for p in SYSTEMS.values()])

    def test_a_non_numeric_stable_is_refused(self):
        for stable in ["latest", "1.0.62-alpha", "<html>", ""]:
            with self.subTest(stable=stable):
                self.log.unlink(missing_ok=True)
                before = self.write_pin("1.0.61")
                result = self.run_release(stable=stable)
                self.assertEqual(result.returncode, 1)
                self.assertIn("plain version string", result.stderr)
                self.assertEqual(self.output.read_text(), before)
                self.assertEqual(self.calls("head"), [])

    def test_a_trailing_newline_on_the_channel_pointer_is_ignored(self):
        result = self.run_release(stable="1.0.62\n", extra_args=["--dry-run"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.expected_pin("1.0.62"))

    def test_dry_run_prints_the_pin_and_writes_nothing(self):
        before = self.write_pin("1.0.61")
        result = self.run_release(extra_args=["--dry-run", "--output", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.expected_pin("1.0.62"))
        self.assertEqual(self.output.read_text(), before)
        self.assertEqual(sorted(p.name for p in self.output.parent.glob(".grok-build-release.*")), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
