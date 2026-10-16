"""Drive wifiman-desktop-release against GraphQL and prefetch fixtures.

The helper's network call and its download both go through overridable
commands, so these tests feed it a GraphQL response and a fake prefetch
instead of network calls.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/wifiman-desktop-release"

HEX = "2bb75b73c092e43592bbd40841628f222000bea95a28389aafe84adaf279cd78"
SRI = "sha256-K7dbc8CS5DWSu9QIQWKPIiAAvqlaKDiar+hK2vJ5zXg="
# Output of `nix hash convert --hash-algo sha256 --to nix32 <SRI>`.
NIX32 = "0y6dg7rdljp8myd3ha2sm6z00812ixi4226lpf93br4jq1rmpdrb"
URL = "https://desktop.wifiman.com/wifiman-desktop-1.3.0-amd64.deb"


def response(*items):
    return json.dumps(
        {
            "data": {
                "releases": {
                    "items": [{"title": title, "version": version} for title, version in items]
                }
            }
        }
    )


SAMPLE = response(
    ("WiFiman Desktop 1.2.8", "1.2.8"),
    ("WiFiman Desktop 1.3.0", "1.3.0"),
    ("WiFiman Android 2.13.0", "2.13.0"),
)

FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
status = int(os.environ.get('FAKE_FETCH_STATUS', '0'))
if status:
    sys.exit(status)
with open(os.environ['FAKE_FETCH_LOG'], 'w') as f:
    f.write(sys.argv[-1] + '\\n' + sys.stdin.read())
sys.stdout.write(os.environ['FAKE_FETCH_BODY'])
"""

FAKE_PREFETCH = """#!/usr/bin/env python3
import os, sys
with open(os.environ['FAKE_PREFETCH_LOG'], 'a') as f:
    f.write(sys.argv[-1] + '\\n')
status = int(os.environ.get('FAKE_PREFETCH_STATUS', '0'))
if status:
    sys.exit(status)
sys.stdout.write(os.environ['FAKE_PREFETCH_OUT'])
"""


class WifimanDesktopReleaseTestCase(unittest.TestCase):
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
        self.output = root / "wifiman-desktop-version.json"

    def run_release(
        self,
        body=SAMPLE,
        extra_args=None,
        fetch_status=0,
        prefetch_out=NIX32 + "\n",
        prefetch_status=0,
    ):
        env = dict(os.environ)
        env["WIFIMAN_DESKTOP_RELEASE_FETCH"] = f"{sys.executable} {self.fetch}"
        env["WIFIMAN_DESKTOP_RELEASE_PREFETCH"] = f"{sys.executable} {self.prefetch}"
        env["FAKE_FETCH_BODY"] = body
        env["FAKE_FETCH_STATUS"] = str(fetch_status)
        env["FAKE_FETCH_LOG"] = str(self.fetch_log)
        env["FAKE_PREFETCH_OUT"] = prefetch_out
        env["FAKE_PREFETCH_STATUS"] = str(prefetch_status)
        env["FAKE_PREFETCH_LOG"] = str(self.prefetch_log)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def prefetched(self):
        if not self.prefetch_log.exists():
            return []
        return self.prefetch_log.read_text().splitlines()

    def write_pin(self, version):
        self.output.write_text(
            json.dumps({"version": version, "sha256": "2" * 64, "hash": "sha256-unused"}, indent=2)
            + "\n"
        )

    def test_resolves_the_highest_desktop_version(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            json.dumps({"version": "1.3.0", "sha256": HEX, "hash": SRI}, indent=2) + "\n",
        )
        self.assertEqual(self.prefetched(), [URL])

    def test_posts_the_graphql_query_to_the_source_url(self):
        result = self.run_release(extra_args=["--dry-run", "--source-url", "https://example.invalid/gql"])
        self.assertEqual(result.returncode, 0, result.stderr)
        url, body = self.fetch_log.read_text().split("\n", 1)
        self.assertEqual(url, "https://example.invalid/gql")
        self.assertEqual(
            json.loads(body),
            {"query": 'query { releases(tags: ["wifiman"]) { items { title version } } }'},
        )

    def test_ignores_a_higher_non_desktop_item(self):
        body = response(("WiFiman Android 9.9.9", "9.9.9"), ("WiFiman Desktop 1.3.0", "1.3.0"))
        result = self.run_release(body=body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["version"], "1.3.0")
        self.assertEqual(self.prefetched(), [URL])

    def test_numeric_version_comparison_beats_lexical(self):
        body = response(("WiFiman Desktop 1.9.0", "1.9.0"), ("WiFiman Desktop 1.10.0", "1.10.0"))
        result = self.run_release(body=body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["version"], "1.10.0")

    def test_skips_a_non_dotted_version(self):
        body = response(("WiFiman Desktop beta", "2.0.0-beta"), ("WiFiman Desktop 1.3.0", "1.3.0"))
        result = self.run_release(body=body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["version"], "1.3.0")

    def test_hex_prefetch_output_converts_to_the_same_hash(self):
        result = self.run_release(prefetch_out=HEX.upper() + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["sha256"], HEX)
        self.assertEqual(data["hash"], SRI)

    def test_base32_prefetch_output_converts_to_hex_and_sri(self):
        result = self.run_release(prefetch_out=NIX32)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["sha256"], HEX)
        self.assertEqual(data["hash"], SRI)

    def test_writes_a_newer_version_to_the_pin(self):
        self.write_pin("1.2.8")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(
            self.output.read_text(),
            json.dumps({"version": "1.3.0", "sha256": HEX, "hash": SRI}, indent=2) + "\n",
        )

    def test_writes_a_pin_when_none_exists(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.3.0")

    def test_same_version_leaves_the_pin_and_downloads_nothing(self):
        self.write_pin("1.3.0")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(self.prefetched(), [])

    def test_refuses_a_downgrade_and_downloads_nothing(self):
        self.write_pin("1.4.0")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("is not newer", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(self.prefetched(), [])

    def test_unreadable_existing_pin_is_treated_as_absent(self):
        self.output.write_text(json.dumps([1, 2, 3]))
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], "1.3.0")

    def assert_failure(self, result, message):
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertTrue(result.stderr.startswith("wifiman-desktop-release: "), result.stderr)
        self.assertIn(message, result.stderr)

    def test_no_desktop_item_fails_and_leaves_the_pin(self):
        self.write_pin("1.2.8")
        before = self.output.read_bytes()
        body = response(("WiFiman Android 2.13.0", "2.13.0"))
        result = self.run_release(body=body, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "no Desktop release found")
        self.assertEqual(self.output.read_bytes(), before)

    def test_only_non_dotted_desktop_versions_fail(self):
        result = self.run_release(body=response(("WiFiman Desktop x", "x")))
        self.assert_failure(result, "no Desktop release found")

    def test_malformed_json_fails(self):
        result = self.run_release(body="not json", extra_args=["-o", str(self.output)])
        self.assert_failure(result, "not valid JSON")
        self.assertFalse(self.output.exists())

    def test_missing_keys_fail(self):
        result = self.run_release(body=json.dumps({"data": {}}))
        self.assert_failure(result, "unexpected response shape")

    def test_fetch_error_fails(self):
        result = self.run_release(fetch_status=2, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "failed with status 2")
        self.assertFalse(self.output.exists())

    def test_prefetch_error_fails_and_leaves_the_pin(self):
        self.write_pin("1.2.8")
        before = self.output.read_bytes()
        result = self.run_release(prefetch_status=3, extra_args=["-o", str(self.output)])
        self.assert_failure(result, "failed with status 3")
        self.assertEqual(self.output.read_bytes(), before)

    def test_unparsable_prefetch_output_fails(self):
        result = self.run_release(prefetch_out="garbage\n", extra_args=["-o", str(self.output)])
        self.assert_failure(result, "not a sha256 hash")
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
