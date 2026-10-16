"""Drive opencode-release against fake GitHub latest-release fixtures.

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

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/opencode-release"

TARGET = "opencode-linux-x64.tar.gz"
ARM_TARGET = "opencode-linux-arm64.tar.gz"
DARWIN_TARGET = "opencode-darwin-arm64.zip"
X64_HEX = "13a8fb2978302071b86f9d7e00da9c8895f9cd846978379c3bdc6a5333536c9b"
ARM_HEX = "7900818a6a98881edbbadab4b7525940eff3b9750040c200481f9f56cacee405"
DARWIN_HEX = "c2d0fecd27acf6e08be02c1f5d384614d07495587766bcc4a6bff3971749bb64"
OTHER_HEX = "2148d2485d1e6e48eb918729d86af4ecd438f9b5b63be360fb26005c85f0d853"


def asset(name, hex_digest):
    return {
        "name": name,
        "digest": f"sha256:{hex_digest}",
        "browser_download_url": f"https://github.com/anomalyco/opencode/releases/download/x/{name}",
    }


def release(version, x64_digest=None, x64_count=1, prerelease=False, draft=False,
            tag=None, arm_count=1, darwin_count=1):
    """Build a latest-release body shaped like GitHub's REST API response.

    The x86_64 archive comes last, so a test can edit assets[-1]. The musl,
    baseline, and desktop assets sit beside it, as they do upstream, so a
    prefix or substring match would pick the wrong one.
    """
    assets = [
        asset("opencode-linux-x64-musl.tar.gz", OTHER_HEX),
        asset("opencode-linux-x64-baseline.tar.gz", OTHER_HEX),
        asset("opencode-linux-x64-baseline-musl.tar.gz", OTHER_HEX),
        asset("opencode-linux-arm64-musl.tar.gz", OTHER_HEX),
        asset("opencode-darwin-x64.zip", OTHER_HEX),
        asset("opencode-desktop-linux-x86_64.AppImage", OTHER_HEX),
        asset("latest-linux.yml", OTHER_HEX),
    ]
    for _ in range(darwin_count):
        assets.append(asset(DARWIN_TARGET, DARWIN_HEX))
    for _ in range(arm_count):
        assets.append(asset(ARM_TARGET, ARM_HEX))
    for _ in range(x64_count):
        entry = asset(TARGET, X64_HEX)
        if x64_digest is not None:
            entry["digest"] = x64_digest
        assets.append(entry)
    return json.dumps(
        {
            "tag_name": tag if tag is not None else f"v{version}",
            "prerelease": prerelease,
            "draft": draft,
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


class OpencodeReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.output = root / "opencode-release.json"

    def run_release(self, body=None, extra_args=None, status=0, fetch=None):
        if body is None:
            body = release("1.19.3")
        env = dict(os.environ)
        env["OPENCODE_RELEASE_FETCH"] = (
            f"{sys.executable} {self.fetch}" if fetch is None else fetch
        )
        env["FAKE_BODY"] = body
        env["FAKE_STATUS"] = str(status)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def write_pin(self, version):
        self.output.write_text(json.dumps({"version": version, "platforms": {}}))

    def assert_refused(self, result, needle):
        self.assertEqual(result.returncode, 1)
        self.assertIn("opencode-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertFalse(self.output.exists())

    def assert_refused_keeping_pin(self, body, needle):
        self.write_pin("1.19.2")
        before = self.output.read_bytes()
        result = self.run_release(body=body, extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("opencode-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertEqual(self.output.read_bytes(), before)

    def test_writes_version_and_each_digest_when_newer(self):
        self.write_pin("1.19.2")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(
            json.loads(self.output.read_text()),
            {
                "version": "1.19.3",
                "platforms": {
                    "x86_64-linux": {"asset": TARGET, "sha256": X64_HEX, "hash": sri(X64_HEX)},
                    "aarch64-linux": {
                        "asset": ARM_TARGET,
                        "sha256": ARM_HEX,
                        "hash": sri(ARM_HEX),
                    },
                    "aarch64-darwin": {
                        "asset": DARWIN_TARGET,
                        "sha256": DARWIN_HEX,
                        "hash": sri(DARWIN_HEX),
                    },
                },
            },
        )

    def test_uppercase_digest_is_pinned_lowercase(self):
        body = json.loads(release("1.19.3"))
        body["assets"][-1]["digest"] = "sha256:" + X64_HEX.upper()
        result = self.run_release(body=json.dumps(body), extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = json.loads(self.output.read_text())["platforms"]["x86_64-linux"]
        self.assertEqual(pin["sha256"], X64_HEX)
        self.assertEqual(pin["hash"], sri(X64_HEX))

    def test_writes_a_pin_when_none_exists(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.19.3")

    def test_numeric_version_comparison_beats_lexical(self):
        self.write_pin("1.9.0")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.19.3")

    def test_same_version_leaves_the_pin_byte_identical(self):
        self.write_pin("1.19.3")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_older_version_leaves_the_pin_byte_identical(self):
        self.write_pin("1.20.0")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_malformed_existing_pin_is_treated_as_absent(self):
        self.output.write_text("{not json")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.19.3")

    def test_unparseable_pinned_version_is_replaced(self):
        self.write_pin("garbage")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.19.3")

    def test_unwritable_output_path_fails_with_a_message(self):
        missing = Path(self.tmp.name) / "missing" / "opencode-release.json"
        result = self.run_release(extra_args=["-o", str(missing)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("opencode-release:", result.stderr)
        self.assertFalse(missing.exists())

    def test_refuses_a_release_without_a_pinned_asset(self):
        for kwargs, needle in [
            ({"x64_count": 0}, TARGET),
            ({"arm_count": 0}, ARM_TARGET),
            ({"darwin_count": 0}, DARWIN_TARGET),
        ]:
            with self.subTest(missing=needle):
                self.output.unlink(missing_ok=True)
                self.assert_refused(
                    self.run_release(
                        body=release("1.19.3", **kwargs), extra_args=["-o", str(self.output)]
                    ),
                    needle,
                )
                self.assert_refused_keeping_pin(release("1.19.3", **kwargs), needle)

    def test_refuses_two_matching_assets(self):
        result = self.run_release(
            body=release("1.19.3", x64_count=2), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, TARGET)

    def test_refuses_a_digest_that_is_not_sha256(self):
        for digest in ["sha512:" + X64_HEX, "sha256:abc123", X64_HEX, None]:
            with self.subTest(digest=digest):
                body = json.loads(release("1.19.3", x64_digest=digest or ""))
                if digest is None:
                    del body["assets"][-1]["digest"]
                result = self.run_release(
                    body=json.dumps(body), extra_args=["-o", str(self.output)]
                )
                self.assert_refused(result, "digest")

    def test_refuses_a_prerelease_or_draft(self):
        for kwargs in [{"prerelease": True}, {"draft": True}]:
            with self.subTest(**kwargs):
                self.assert_refused_keeping_pin(release("1.20.0", **kwargs), "prerelease or draft")

    def test_refuses_a_release_that_omits_the_draft_flag(self):
        body = json.loads(release("1.20.0"))
        del body["draft"]
        self.assert_refused_keeping_pin(json.dumps(body), "prerelease or draft")

    def test_refuses_a_tag_without_the_v_prefix(self):
        result = self.run_release(
            body=release("1.19.3", tag="1.19.3"), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, "'1.19.3'")

    def test_refuses_a_non_numeric_version(self):
        result = self.run_release(
            body=release("1.20.0-beta.1"), extra_args=["-o", str(self.output)]
        )
        self.assert_refused(result, "1.20.0-beta.1")

    def test_refuses_a_body_that_is_not_json(self):
        result = self.run_release(body="<html>rate limited</html>")
        self.assertEqual(result.returncode, 1)
        self.assertIn("opencode-release:", result.stderr)

    def test_fetch_error_fails_naming_the_url(self):
        result = self.run_release(status=22, extra_args=["-o", str(self.output)])
        self.assert_refused(result, "releases/latest failed with status 22")

    def test_dry_run_prints_json_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout)["platforms"]["x86_64-linux"]["hash"], sri(X64_HEX)
        )
        self.assertFalse(self.output.exists())

    def test_empty_fetch_command_fails(self):
        result = self.run_release(fetch="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("OPENCODE_RELEASE_FETCH is empty", result.stderr)


if __name__ == "__main__":
    unittest.main()
