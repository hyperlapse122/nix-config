"""Drive claude-code-release against fake /latest and manifest.zst.json fixtures.

The helper's network calls go through an overridable command, so these tests
feed it two-call fixtures keyed by the requested URL instead of network calls.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/claude-code-release"

SAMPLE_MANIFEST = {
    "version": "2.1.280",
    "platforms": {
        "linux-x64": {
            "binary": "claude.zst",
            "checksum": "27910e2ae704d8f2e8024897d8fdf1e7710807baf4f6982c0e3797c058315384",
            "size": 82761570,
        },
    },
}

FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
url = sys.argv[-1]
if url.endswith('/latest'):
    status = int(os.environ.get('FAKE_LATEST_STATUS', '0'))
    if status:
        sys.exit(status)
    sys.stdout.write(os.environ.get('FAKE_LATEST_BODY', ''))
else:
    status = int(os.environ.get('FAKE_MANIFEST_STATUS', '0'))
    if status:
        sys.exit(status)
    sys.stdout.write(os.environ.get('FAKE_MANIFEST_BODY', ''))
"""


class ClaudeCodeReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)

    def run_release(
        self,
        latest_body="2.1.280",
        manifest_body=None,
        extra_args=None,
        latest_status=0,
        manifest_status=0,
    ):
        if manifest_body is None:
            manifest_body = json.dumps(SAMPLE_MANIFEST)
        env = dict(os.environ)
        env["CLAUDE_CODE_RELEASE_FETCH"] = f"{sys.executable} {self.fetch}"
        env["FAKE_LATEST_BODY"] = latest_body
        env["FAKE_LATEST_STATUS"] = str(latest_status)
        env["FAKE_MANIFEST_BODY"] = manifest_body
        env["FAKE_MANIFEST_STATUS"] = str(manifest_status)
        args = [sys.executable, str(SCRIPT)]
        if extra_args:
            args.extend(extra_args)
        else:
            args.append("--dry-run")
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def test_writes_to_output_file_when_newer(self):
        output_file = Path(self.tmp.name) / "manifest.json"
        result = self.run_release(extra_args=["-o", str(output_file)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(output_file.exists())
        data = json.loads(output_file.read_text())
        self.assertEqual(data["version"], "2.1.280")
        self.assertIn("updated", result.stdout)

    def test_idempotent_rerun_reports_already_up_to_date(self):
        output_file = Path(self.tmp.name) / "manifest.json"
        output_file.write_text(json.dumps(SAMPLE_MANIFEST))
        result = self.run_release(extra_args=["-o", str(output_file)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)

    def test_refuses_a_downgrade(self):
        output_file = Path(self.tmp.name) / "manifest.json"
        newer = dict(SAMPLE_MANIFEST, version="2.1.280")
        output_file.write_text(json.dumps(newer))
        result = self.run_release(latest_body="2.1.279", extra_args=["-o", str(output_file)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        data = json.loads(output_file.read_text())
        self.assertEqual(data["version"], "2.1.280")

    def test_refuses_manifest_missing_target_platform(self):
        manifest = {"version": "2.1.280", "platforms": {"darwin-arm64": {"binary": "claude.zst", "checksum": "0" * 64}}}
        result = self.run_release(manifest_body=json.dumps(manifest))
        self.assertEqual(result.returncode, 1)
        self.assertIn("linux-x64", result.stderr)

    def test_latest_fetch_error_fails(self):
        result = self.run_release(latest_status=2)
        self.assertEqual(result.returncode, 1)
        self.assertIn("failed with status 2", result.stderr)

    def test_manifest_fetch_error_fails(self):
        result = self.run_release(manifest_status=2)
        self.assertEqual(result.returncode, 1)
        self.assertIn("failed with status 2", result.stderr)


if __name__ == "__main__":
    unittest.main()
