"""Drive codex-release against fake GitHub latest-release fixtures.

The helper's network call goes through an overridable command, so these tests
feed it a fixture body instead of a network call.
"""

import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/codex-release"

TARGET = "codex-x86_64-unknown-linux-musl.tar.gz"
ARM_TARGET = "codex-aarch64-unknown-linux-musl.tar.gz"
MUSL_HEX = "b48ca1b2d6b1bf42b944e02c3d937c898e24651916684cdc35fdedf31b291bcb"
ARM_HEX = "cd5f307b3fcd6080773e684b86c3114a67d4f1c61dc447be09876b552eb4bea7"
GNU_HEX = "2148d2485d1e6e48eb918729d86af4ecd438f9b5b63be360fb26005c85f0d853"


def asset(name, hex_digest):
    return {
        "name": name,
        "digest": f"sha256:{hex_digest}",
        "browser_download_url": f"https://github.com/openai/codex/releases/download/x/{name}",
    }


def release(version, musl_digest=None, musl_count=1, prerelease=False, tag=None,
            arm_count=1):
    """Build a latest-release body shaped like GitHub's REST API response."""
    assets = [
        asset("codex-x86_64-unknown-linux-gnu.tar.gz", GNU_HEX),
        asset("codex-aarch64-unknown-linux-gnu.tar.gz", GNU_HEX),
        asset("codex-x86_64-unknown-linux-musl.zst", GNU_HEX),
    ]
    for _ in range(arm_count):
        assets.append(asset(ARM_TARGET, ARM_HEX))
    for _ in range(musl_count):
        entry = asset(TARGET, MUSL_HEX)
        if musl_digest is not None:
            entry["digest"] = musl_digest
        assets.append(entry)
    return json.dumps(
        {
            "tag_name": tag if tag is not None else f"rust-v{version}",
            "prerelease": prerelease,
            "draft": False,
            "assets": assets,
        }
    )


def sri(hex_digest):
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_digest)).decode("ascii")


FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
status = int(os.environ.get('FAKE_STATUS', '0'))
if status:
    sys.exit(status)
sys.stdout.write(os.environ.get('FAKE_BODY', ''))
"""


class CodexReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.output = root / "codex-release.json"

    def run_release(self, body=None, extra_args=None, status=0, fetch=None):
        if body is None:
            body = release("0.159.3")
        env = dict(os.environ)
        env["CODEX_RELEASE_FETCH"] = (
            f"{sys.executable} {self.fetch}" if fetch is None else fetch
        )
        env["FAKE_BODY"] = body
        env["FAKE_STATUS"] = str(status)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def write_pin(self, version):
        self.output.write_text(
            json.dumps({"version": version, "sha256": "0" * 64, "hash": sri("0" * 64)})
        )

    def assert_refused(self, result, needle):
        self.assertEqual(result.returncode, 1)
        self.assertIn("codex-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertFalse(self.output.exists())

    def test_writes_version_and_each_musl_digest_when_newer(self):
        self.write_pin("0.159.2")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(
            json.loads(self.output.read_text()),
            {
                "version": "0.159.3",
                "platforms": {
                    "x86_64-linux": {"asset": TARGET, "sha256": MUSL_HEX, "hash": sri(MUSL_HEX)},
                    "aarch64-linux": {"asset": ARM_TARGET, "sha256": ARM_HEX, "hash": sri(ARM_HEX)},
                },
            },
        )

    def test_refuses_a_release_without_the_aarch64_musl_asset(self):
        result = self.run_release(
            body=release("0.159.3", arm_count=0), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, ARM_TARGET)

    def test_writes_a_pin_when_none_exists(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "0.159.3")

    def test_numeric_version_comparison_beats_lexical(self):
        self.write_pin("0.99.0")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "0.159.3")

    def test_same_version_leaves_the_pin_byte_identical(self):
        self.write_pin("0.159.3")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_refuses_a_downgrade(self):
        self.write_pin("0.160.0")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_malformed_existing_pin_is_treated_as_absent(self):
        self.output.write_text("{not json")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "0.159.3")

    def test_refuses_a_release_without_the_musl_asset(self):
        result = self.run_release(
            body=release("0.159.3", musl_count=0), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, TARGET)

    def test_refuses_two_matching_assets(self):
        result = self.run_release(
            body=release("0.159.3", musl_count=2), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, TARGET)

    def test_refuses_a_digest_that_is_not_sha256(self):
        for digest in ["sha512:" + MUSL_HEX, "sha256:abc123", MUSL_HEX, None]:
            with self.subTest(digest=digest):
                body = json.loads(release("0.159.3", musl_digest=digest or ""))
                if digest is None:
                    del body["assets"][-1]["digest"]
                result = self.run_release(
                    body=json.dumps(body), extra_args=["-o", str(self.output)]
                )
                self.assert_refused(result, "digest")

    def test_refuses_a_prerelease(self):
        result = self.run_release(
            body=release("0.160.0", prerelease=True), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, "prerelease")

    def test_refuses_a_tag_without_the_rust_prefix(self):
        result = self.run_release(
            body=release("0.159.3", tag="v0.159.3"), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, "v0.159.3")

    def test_refuses_a_non_numeric_version(self):
        result = self.run_release(
            body=release("0.160.0-alpha.1"), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, "0.160.0-alpha.1")

    def test_refuses_a_body_that_is_not_json(self):
        result = self.run_release(body="<html>rate limited</html>")
        self.assertEqual(result.returncode, 1)
        self.assertIn("codex-release:", result.stderr)

    def test_fetch_error_fails_naming_the_url(self):
        result = self.run_release(status=22, extra_args=["-o", str(self.output)])
        self.assert_refused(result, "releases/latest failed with status 22")

    def test_dry_run_prints_json_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout)["platforms"]["x86_64-linux"]["hash"], sri(MUSL_HEX)
        )
        self.assertFalse(self.output.exists())

    def test_empty_fetch_command_fails(self):
        result = self.run_release(fetch="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("CODEX_RELEASE_FETCH is empty", result.stderr)


if __name__ == "__main__":
    unittest.main()
