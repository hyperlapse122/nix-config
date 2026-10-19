"""Drive grok-bot-release against feed and prefetch fixtures.

The helper's download feeds and its .deb downloads both go through overridable
commands, so these tests feed it JSON responses and fake prefetch outputs
instead of network calls.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/grok-bot-release"

X64_FEED_URL = "https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand"
ARM64_FEED_URL = "https://api2.cursor.sh/updates/api/download/stable/linux-arm64/sand"

X64_DEB_URL = (
    "https://downloads.cursor.com/grokbot/stable/abc1234/linux/x64/grok-bot_0.71.2_amd64.deb"
)
ARM64_DEB_URL = (
    "https://downloads.cursor.com/grokbot/stable/abc1234/linux/arm64/grok-bot_0.71.2_arm64.deb"
)

X64_SRI = "sha256-K7dbc8CS5DWSu9QIQWKPIiAAvqlaKDiar+hK2vJ5zXg="
ARM64_SRI = "sha256-7ENOgxr9z86HeA8oFf1zKx34pKjelqSRcWrXXRNgWk4="


def sample_feed_response(version, deb_url):
    return json.dumps({
        "downloadUrl": deb_url.replace(".deb", ".AppImage"),
        "debUrl": deb_url,
        "rpmUrl": deb_url.replace(".deb", ".rpm"),
        "version": version,
        "commitSha": "abc1234",
    })


SAMPLE_X64 = sample_feed_response("0.71.2", X64_DEB_URL)
SAMPLE_ARM64 = sample_feed_response("0.71.2", ARM64_DEB_URL)

FAKE_FETCH = """#!/usr/bin/env python3
import os, sys, time
url = sys.argv[-1]
time.sleep(float(os.environ.get('FAKE_FETCH_SLEEP', '0')))
status = int(os.environ.get('FAKE_FETCH_STATUS', '0'))
if status:
    sys.exit(status)
with open(os.environ['FAKE_FETCH_LOG'], 'a') as f:
    f.write(url + '\\n')
if 'linux-x64' in url:
    sys.stdout.write(os.environ.get('FAKE_FETCH_X64_BODY', os.environ['FAKE_FETCH_DEFAULT_X64']))
elif 'linux-arm64' in url:
    sys.stdout.write(os.environ.get('FAKE_FETCH_ARM64_BODY', os.environ['FAKE_FETCH_DEFAULT_ARM64']))
else:
    sys.stdout.write(os.environ.get('FAKE_FETCH_BODY', '{}'))
"""

FAKE_PREFETCH = """#!/usr/bin/env python3
import json, os, sys
url = sys.argv[-1]
with open(os.environ['FAKE_PREFETCH_LOG'], 'a') as f:
    f.write(url + '\\n')
status = int(os.environ.get('FAKE_PREFETCH_STATUS', '0'))
if status:
    sys.exit(status)
override = os.environ.get('FAKE_PREFETCH_OUT')
if override is not None:
    sys.stdout.write(override)
    sys.exit(0)
sri = os.environ['FAKE_ARM64_SRI'] if 'arm64' in url else os.environ['FAKE_X64_SRI']
sys.stdout.write(json.dumps({'hash': sri, 'storePath': '/nix/store/fake-' + os.path.basename(url)}) + '\\n')
"""


class GrokBotReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.prefetch = root / "fake-prefetch"
        self.prefetch.write_text(FAKE_PREFETCH)
        self.fetch_log = root / "fetch.log"
        self.prefetch_log = root / "prefetch.log"
        self.output = root / "grok-bot-release.json"

    def run_release(
        self,
        extra_args=None,
        fetch_status=0,
        x64_body=None,
        arm64_body=None,
        prefetch_status=0,
        prefetch_out=None,
        extra_env=None,
    ):
        env = dict(os.environ)
        env["GROK_BOT_RELEASE_FETCH"] = f"{sys.executable} {self.fetch}"
        env["GROK_BOT_RELEASE_PREFETCH"] = f"{sys.executable} {self.prefetch}"
        env["FAKE_FETCH_DEFAULT_X64"] = SAMPLE_X64
        env["FAKE_FETCH_DEFAULT_ARM64"] = SAMPLE_ARM64
        if x64_body is not None:
            env["FAKE_FETCH_X64_BODY"] = x64_body
        if arm64_body is not None:
            env["FAKE_FETCH_ARM64_BODY"] = arm64_body
        env["FAKE_FETCH_STATUS"] = str(fetch_status)
        env["FAKE_FETCH_LOG"] = str(self.fetch_log)
        env["FAKE_PREFETCH_STATUS"] = str(prefetch_status)
        env["FAKE_PREFETCH_LOG"] = str(self.prefetch_log)
        env["FAKE_X64_SRI"] = X64_SRI
        env["FAKE_ARM64_SRI"] = ARM64_SRI
        if prefetch_out is not None:
            env["FAKE_PREFETCH_OUT"] = prefetch_out
        env.update(extra_env or {})
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def write_pin(self, version):
        self.output.write_text(
            json.dumps(
                {
                    "version": version,
                    "platforms": {
                        "x86_64-linux": {"url": X64_DEB_URL, "hash": X64_SRI},
                        "aarch64-linux": {"url": ARM64_DEB_URL, "hash": ARM64_SRI},
                    },
                },
                indent=2,
            )
            + "\n"
        )

    def assert_failure(self, result, message):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stderr.startswith("grok-bot-release: "), result.stderr)
        self.assertIn(message, result.stderr)

    def test_both_architectures_valid_writes_pin(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        expected = {
            "version": "0.71.2",
            "platforms": {
                "x86_64-linux": {"url": X64_DEB_URL, "hash": X64_SRI},
                "aarch64-linux": {"url": ARM64_DEB_URL, "hash": ARM64_SRI},
            },
        }
        self.assertEqual(json.loads(self.output.read_text()), expected)
        self.assertEqual(
            self.output.read_text(),
            json.dumps(expected, indent=2) + "\n",
        )

    def test_architectures_disagree_on_version_fails_and_leaves_output(self):
        self.write_pin("0.70.0")
        before = self.output.read_bytes()
        arm64_diff = sample_feed_response("0.71.1", ARM64_DEB_URL.replace("0.71.2", "0.71.1"))
        result = self.run_release(arm64_body=arm64_diff, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "0.71.2")
        self.assertIn("0.71.1", result.stderr)
        self.assertEqual(self.output.read_bytes(), before)

    def test_deb_url_outside_allowed_prefix_fails_and_leaves_output(self):
        self.write_pin("0.70.0")
        before = self.output.read_bytes()
        evil_body = sample_feed_response("0.71.2", "https://malicious.example.com/grok-bot.deb")
        result = self.run_release(x64_body=evil_body, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "https://downloads.cursor.com/grokbot/")
        self.assertEqual(self.output.read_bytes(), before)

    def test_feed_error_object_without_version_fails(self):
        error_json = json.dumps({"error": "Platform not supported"})
        result = self.run_release(x64_body=error_json, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "Platform not supported")
        self.assertFalse(self.output.exists())

    def test_fetch_command_non_zero_fails_naming_url(self):
        result = self.run_release(fetch_status=2, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand")
        self.assertFalse(self.output.exists())

    def test_prefetch_fails_or_prints_no_hash_leaves_output(self):
        self.write_pin("0.70.0")
        before = self.output.read_bytes()
        # Subcase 1: prefetch command exits non-zero
        result = self.run_release(prefetch_status=3, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "failed with status 3")
        self.assertEqual(self.output.read_bytes(), before)

        # Subcase 2: prefetch prints invalid output without hash
        for bad_out in ("garbage\n", json.dumps({"storePath": "/nix/store/foo"}), "[]\n"):
            with self.subTest(bad_out=bad_out):
                result = self.run_release(prefetch_out=bad_out, extra_args=["-o", str(self.output)])
                self.assert_failure(result, "carries no sha256 SRI hash")
                self.assertEqual(self.output.read_bytes(), before)

    def test_current_pin_newer_leaves_pin_untouched(self):
        self.write_pin("0.72.0")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_bytes(), before)
        if self.prefetch_log.exists():
            self.assertEqual(self.prefetch_log.read_text(), "")

    def test_current_pin_equals_feed_exits_zero_up_to_date(self):
        self.write_pin("0.71.2")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)
        if self.prefetch_log.exists():
            self.assertEqual(self.prefetch_log.read_text(), "")

    def test_dry_run_prints_resolved_json_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["version"], "0.71.2")
        self.assertEqual(data["platforms"]["x86_64-linux"]["hash"], X64_SRI)
        self.assertEqual(data["platforms"]["aarch64-linux"]["hash"], ARM64_SRI)
        self.assertFalse(self.output.exists())

    def test_newer_feed_replaces_older_pin_after_querying_both_feeds(self):
        self.write_pin("0.70.0")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(json.loads(self.output.read_text())["version"], "0.71.2")
        self.assertEqual(
            sorted(self.fetch_log.read_text().split()), sorted([X64_FEED_URL, ARM64_FEED_URL])
        )
        self.assertEqual(
            sorted(self.prefetch_log.read_text().split()), sorted([X64_DEB_URL, ARM64_DEB_URL])
        )

    def test_malformed_pinned_version_is_replaced(self):
        self.write_pin("not-a-version")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "0.71.2")

    def test_arm64_feed_naming_the_amd64_deb_fails_and_leaves_output(self):
        self.write_pin("0.70.0")
        before = self.output.read_bytes()
        result = self.run_release(
            arm64_body=sample_feed_response("0.71.2", X64_DEB_URL),
            extra_args=["-o", str(self.output)],
        )
        self.assert_failure(result, "grok-bot_0.71.2_arm64.deb")
        self.assertEqual(self.output.read_bytes(), before)

    def test_deb_url_for_another_version_fails(self):
        result = self.run_release(
            x64_body=sample_feed_response("0.71.2", X64_DEB_URL.replace("0.71.2", "0.70.0"))
        )
        self.assert_failure(result, "grok-bot_0.71.2_amd64.deb")

    def test_feed_body_that_is_not_json_fails(self):
        result = self.run_release(x64_body="<html>moved</html>")
        self.assert_failure(result, "invalid JSON")

    def test_feed_version_that_is_not_numeric_fails(self):
        result = self.run_release(x64_body=sample_feed_response("latest", X64_DEB_URL))
        self.assert_failure(result, "invalid version")

    def test_hung_feed_fails_after_the_timeout(self):
        result = self.run_release(
            extra_env={"FAKE_FETCH_SLEEP": "5", "GROK_BOT_RELEASE_TIMEOUT": "1"}
        )
        self.assert_failure(result, "timed out after 1s")


if __name__ == "__main__":
    unittest.main()
