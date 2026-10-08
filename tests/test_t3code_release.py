"""Drive t3code-release against fake GitHub release-list and source fixtures.

The helper's network calls go through an overridable command, so these tests
feed it fixture bodies instead of network calls: the release list, and the
Antigravity release table from the T3 Code source at the selected tag.
"""

import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/t3code-release"

FAKE_TOKEN = "ghp_fake0000000000000000000000000000test"

APPIMAGE_X64_HEX = "7521793d4dc87f2b985f88b48b070bedf33a1f590cca34a96c9e7ca0b1fe298b"
APPIMAGE_ARM_HEX = "784939b3fc0aec185df9148893c22b0ae10abb6e32d03905474c5a43ba511508"
CLI_X64_HEX = "5f9e29cf2712c87736556c99ea580606b399897cb846c2401a434a0d05c4eeca"
CLI_ARM_HEX = "73f03e41f2173a9695bb60e2867f14133cf396e0340af6cc8e0ceecd4efcd7d4"
ZIP_DARWIN_HEX = "d576a1481c61ff800d013f33295518794c8675da1d30b945dc7c0b587cfdfee5"
CLI_DARWIN_HEX = "02c191e2a3ed5c3d8c9808d6039884cda18e72426130d062bfbd1b024a5dc3fe"
OTHER_HEX = "6ec2232f168c00aa108c04218e92666a7df2f4c2b71c1e93c734294ae71359d0"

AGY_VERSION = "9.8.7"
AGY_SOURCE_PATH = "apps/server/src/provider/antigravityRelease.ts"

# Node platform key, Nix system, and (url, sha256, archive bytes, executable
# bytes, harness bytes) of each releaseAssets entry the pin needs.
AGY_PLATFORMS = {
    "darwin-arm64": (
        "aarch64-darwin",
        "https://dl.google.com/agy-extensions/releases/macos/agy-acp-server-9.8.7-darwin-arm64.zip",
        "11d97045f7b4fe81175a107cdf16f9c51484e3c78a5162cae415338bb6aa5b88",
        111_456_901,
        278_535_401,
        118_611_301,
    ),
    "linux-x64": (
        "x86_64-linux",
        "https://dl.google.com/agy-extensions/releases/linux/agy-acp-server-9.8.7-linux-x86_64.zip",
        "22b60956af0a9d76220a4db91ca9ac88e2a2372ad68f985ab5fceace6b825b96",
        333_727_102,
        926_533_902,
        130_388_002,
    ),
    "linux-arm64": (
        "aarch64-linux",
        "https://dl.google.com/agy-extensions/releases/linux/agy-acp-server-9.8.7-linux-arm64.zip",
        "330b0bc0fb858e88f4df404d4cedf80bf9298c178291e39e383d6c50b111cbdf",
        321_690_303,
        930_848_903,
        123_224_903,
    ),
}


def agy_entry(key, sha256=None):
    _, url, hex_digest, archive, exe, harness = AGY_PLATFORMS[key]
    return f"""  [
    "{key}",
    {{
      version: ANTIGRAVITY_RELEASE_VERSION,
      url: "{url}",
      sha256: "{hex_digest if sha256 is None else sha256}",
      archiveBytes: {archive:_},
      executable: {{ name: "agy_acp_server.par", bytes: {exe:_} }},
      harness: {{ name: "localharness_external", bytes: {harness:_} }},
    }},
  ],
"""


def agy_source(omit=(), sha256s=None):
    """Build antigravityRelease.ts shaped like the T3 Code source file."""
    sha256s = sha256s or {}
    entries = "".join(
        agy_entry(key, sha256s.get(key)) for key in AGY_PLATFORMS if key not in omit
    )
    # A platform no host in this flake needs, which the pin must skip.
    entries += """  [
    "win32-x64",
    {
      version: ANTIGRAVITY_RELEASE_VERSION,
      url: "https://dl.google.com/agy-extensions/releases/windows/agy-acp-server-9.8.7-windows-x86_64.zip",
      sha256: "65215e0688681fa3116e048a9eab27ef53af1bbd6f3da3f1c52bd4911d8b17f9",
      archiveBytes: 124_509_787,
      executable: { name: "agy_acp_server.exe", bytes: 81_437_336 },
      harness: { name: "localharness_external.exe", bytes: 145_548_952 },
    },
  ],
"""
    return f"""const ANTIGRAVITY_RELEASE_VERSION = "{AGY_VERSION}";

export interface AntigravityReleaseAsset {{
  readonly version: string;
  readonly executable: {{
    readonly name: string;
    readonly bytes: number;
  }};
}}

const releaseAssets = new Map<string, AntigravityReleaseAsset>([
{entries}]);
"""


def expected_antigravity():
    return {
        system: {
            "platform": key,
            "version": AGY_VERSION,
            "url": url,
            "sha256": hex_digest,
            "hash": sri(hex_digest),
            "archiveBytes": archive,
            "executable": {"name": "agy_acp_server.par", "bytes": exe},
            "harness": {"name": "localharness_external", "bytes": harness},
        }
        for key, (system, url, hex_digest, archive, exe, harness) in AGY_PLATFORMS.items()
    }


def target_assets(version):
    return {
        "x86_64-linux": {
            "desktop": (f"T3-Code-{version}-x86_64.AppImage", APPIMAGE_X64_HEX),
            "cli": (f"t3-{version}-linux-x64.tar.gz", CLI_X64_HEX),
        },
        "aarch64-linux": {
            "desktop": (f"T3-Code-{version}-arm64.AppImage", APPIMAGE_ARM_HEX),
            "cli": (f"t3-{version}-linux-arm64.tar.gz", CLI_ARM_HEX),
        },
        "aarch64-darwin": {
            "desktop": (f"T3-Code-{version}-arm64.zip", ZIP_DARWIN_HEX),
            "cli": (f"t3-{version}-darwin-arm64.tar.gz", CLI_DARWIN_HEX),
        },
    }


def asset(name, hex_digest):
    return {
        "name": name,
        "digest": f"sha256:{hex_digest}",
        "browser_download_url": f"https://github.com/pingdotgg/t3code/releases/download/x/{name}",
    }


def release(tag, prerelease=True, draft=False, omit=(), duplicate=(), digests=None):
    """Build one release object shaped like GitHub's REST API response."""
    version = tag[1:]
    assets = [
        asset(f"T3-Code-{version}-amd64.deb", OTHER_HEX),
        asset(f"T3-Code-{version}-arm64.zip.blockmap", OTHER_HEX),
        asset(f"t3-{version}-win32-arm64.zip", OTHER_HEX),
        asset("SHA256SUMS", OTHER_HEX),
    ]
    for components in target_assets(version).values():
        for name, hex_digest in components.values():
            if name in omit:
                continue
            entry = asset(name, hex_digest)
            if digests and name in digests:
                entry["digest"] = digests[name]
            assets.append(entry)
            if name in duplicate:
                assets.append(asset(name, hex_digest))
    return {"tag_name": tag, "prerelease": prerelease, "draft": draft, "assets": assets}


DEFAULT_LIST_URL = "https://api.github.com/repos/pingdotgg/t3code/releases?per_page=50"

NEWEST = "v0.0.46-nightly.20261004.2644"
NEWEST_VERSION = NEWEST[1:]


def release_list(newest=None):
    """A stable, a newer preview, and two nightlies, newest nightly not first."""
    newest = newest if newest is not None else release(NEWEST)
    return json.dumps(
        [
            release("v0.0.47-preview.20261005.2700"),
            release("v0.0.46-nightly.20261003.2638"),
            release("v0.0.47", prerelease=False),
            newest,
        ]
    )


def expected_pin(tag):
    version = tag[1:]
    return {
        "version": version,
        "tag": tag,
        "platforms": {
            system: {
                component: {"asset": name, "sha256": hex_digest, "hash": sri(hex_digest)}
                for component, (name, hex_digest) in components.items()
            }
            for system, components in target_assets(version).items()
        },
        "antigravity": expected_antigravity(),
    }


def sri(hex_digest):
    return "sha256-" + base64.b64encode(bytes.fromhex(hex_digest)).decode("ascii")


# Logs each call's stdin and arguments as one JSON line, and answers a URL
# for the Antigravity source file with FAKE_SOURCE, any other with FAKE_BODY.
FAKE_FETCH = """#!/usr/bin/env python3
import json, os, sys
with open(os.environ['FAKE_STDIN_LOG'], 'a') as f:
    f.write(json.dumps(sys.stdin.read()) + '\\n')
with open(os.environ['FAKE_ARGS_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
status = int(os.environ.get('FAKE_STATUS', '0'))
if status:
    sys.exit(status)
if sys.argv[-1].endswith('antigravityRelease.ts'):
    sys.stdout.write(os.environ.get('FAKE_SOURCE', ''))
else:
    sys.stdout.write(os.environ.get('FAKE_BODY', ''))
"""


class T3codeReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.stdin_log = root / "stdin.log"
        self.args_log = root / "args.log"
        self.output = root / "t3code-release.json"

    def run_release(
        self, body=None, extra_args=None, status=0, fetch=None, token=None, source=None
    ):
        if body is None:
            body = release_list()
        if source is None:
            source = agy_source()
        env = dict(os.environ)
        env.pop("GH_TOKEN", None)
        if token is not None:
            env["GH_TOKEN"] = token
        env["T3CODE_RELEASE_FETCH"] = (
            f"{sys.executable} {self.fetch}" if fetch is None else fetch
        )
        env["FAKE_BODY"] = body
        env["FAKE_SOURCE"] = source
        env["FAKE_STATUS"] = str(status)
        env["FAKE_STDIN_LOG"] = str(self.stdin_log)
        env["FAKE_ARGS_LOG"] = str(self.args_log)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def fetched_urls(self):
        if not self.args_log.exists():
            return []
        return [json.loads(line)[-1] for line in self.args_log.read_text().splitlines()]

    def write_pin(self, version):
        self.output.write_text(json.dumps({"version": version, "tag": f"v{version}"}))

    def assert_refused(self, result, needle):
        self.assertEqual(result.returncode, 1)
        self.assertIn("t3code-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertFalse(self.output.exists())

    def test_picks_the_newest_nightly_over_stable_and_preview(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(json.loads(self.output.read_text()), expected_pin(NEWEST))

    def test_digest_converts_to_the_matching_sri_hash(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = json.loads(result.stdout)
        desktop = pin["platforms"]["aarch64-linux"]["desktop"]
        self.assertEqual(desktop["sha256"], APPIMAGE_ARM_HEX)
        self.assertEqual(
            desktop["hash"], "sha256-" + base64.b64encode(bytes.fromhex(APPIMAGE_ARM_HEX)).decode()
        )

    def test_refuses_a_nightly_missing_the_arm64_appimage(self):
        name = f"T3-Code-{NEWEST_VERSION}-arm64.AppImage"
        body = release_list(release(NEWEST, omit=(name,)))
        result = self.run_release(body=body, extra_args=["-o", str(self.output)])
        self.assert_refused(result, name)

    def test_refuses_a_nightly_missing_a_darwin_asset(self):
        for name in [
            f"T3-Code-{NEWEST_VERSION}-arm64.zip",
            f"t3-{NEWEST_VERSION}-darwin-arm64.tar.gz",
        ]:
            with self.subTest(missing=name):
                body = release_list(release(NEWEST, omit=(name,)))
                result = self.run_release(body=body, extra_args=["-o", str(self.output)])
                self.assert_refused(result, name)

    def test_refuses_a_nightly_with_a_duplicated_asset(self):
        name = f"t3-{NEWEST_VERSION}-linux-x64.tar.gz"
        body = release_list(release(NEWEST, duplicate=(name,)))
        result = self.run_release(body=body, extra_args=["-o", str(self.output)])
        self.assert_refused(result, name)

    def test_refuses_a_digest_that_is_not_sha256(self):
        name = f"t3-{NEWEST_VERSION}-linux-arm64.tar.gz"
        for digest in ["sha512:" + CLI_ARM_HEX, "sha256:abc123", CLI_ARM_HEX, None]:
            with self.subTest(digest=digest):
                body = release_list(release(NEWEST, digests={name: digest}))
                result = self.run_release(body=body, extra_args=["-o", str(self.output)])
                self.assert_refused(result, "digest")

    def test_current_pin_equal_to_newest_writes_nothing(self):
        self.write_pin(NEWEST_VERSION)
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)
        self.assertEqual(self.fetched_urls(), [DEFAULT_LIST_URL])

    def test_same_version_higher_build_is_newer(self):
        self.write_pin("0.0.46-nightly.20261004.2643")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], NEWEST_VERSION)

    def test_lower_date_is_older_even_with_a_higher_build(self):
        # Pinned build number is higher, but its date is later, so the
        # resolved nightly is older and must not replace it.
        self.write_pin("0.0.46-nightly.20261005.2600")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_higher_semver_with_an_older_date_is_newer(self):
        self.write_pin("0.0.45-nightly.20261005.9999")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], NEWEST_VERSION)

    def test_selection_compares_dates_not_list_order_or_build_alone(self):
        body = json.dumps(
            [
                release("v0.0.46-nightly.20261003.2900"),
                release(NEWEST),
                release("v0.0.45-nightly.20261009.3000"),
            ]
        )
        result = self.run_release(body=body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["tag"], NEWEST)

    def test_ignores_drafts_and_nightly_tags_not_marked_prerelease(self):
        body = json.dumps(
            [
                release("v0.0.47-nightly.20261009.3000", draft=True),
                release("v0.0.47-nightly.20261009.3001", prerelease=False),
                release(NEWEST),
            ]
        )
        result = self.run_release(body=body)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["tag"], NEWEST)

    def test_refuses_a_list_without_a_nightly(self):
        body = json.dumps(
            [release("v0.0.47", prerelease=False), release("v0.0.47-preview.20261005.2700")]
        )
        result = self.run_release(body=body, extra_args=["-o", str(self.output)])
        self.assert_refused(result, "no nightly")

    def test_malformed_existing_pin_is_treated_as_absent(self):
        self.output.write_text("{not json")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], NEWEST_VERSION)

    def test_refuses_a_body_that_is_not_a_list(self):
        for body in ["<html>rate limited</html>", json.dumps({"message": "API rate limit"})]:
            with self.subTest(body=body):
                result = self.run_release(body=body, extra_args=["-o", str(self.output)])
                self.assert_refused(result, "release list")

    def test_fetch_error_fails_naming_the_url(self):
        result = self.run_release(status=22, extra_args=["-o", str(self.output)])
        self.assert_refused(result, "releases?per_page=50 failed with status 22")

    def test_dry_run_prints_json_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), expected_pin(NEWEST))
        self.assertFalse(self.output.exists())

    def test_source_url_is_passed_as_the_last_argument(self):
        url = "https://example.invalid/releases?per_page=5"
        result = self.run_release(extra_args=["--dry-run", "--source-url", url])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fetched_urls()[0], url)

    def test_gh_token_is_sent_on_stdin_as_a_bearer_header(self):
        result = self.run_release(token=FAKE_TOKEN)
        self.assertEqual(result.returncode, 0, result.stderr)
        stdins = [json.loads(line) for line in self.stdin_log.read_text().splitlines()]
        # Both the release list and the source file get the header.
        self.assertEqual(stdins, [f"Authorization: Bearer {FAKE_TOKEN}\n"] * 2)
        self.assertNotIn(FAKE_TOKEN, self.args_log.read_text())

    def test_no_header_without_gh_token(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        stdins = [json.loads(line) for line in self.stdin_log.read_text().splitlines()]
        self.assertEqual(stdins, ["", ""])

    def test_fetch_failure_does_not_print_the_token(self):
        result = self.run_release(status=22, token=FAKE_TOKEN)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(FAKE_TOKEN, result.stdout + result.stderr)

    def test_antigravity_entries_match_the_source_at_the_selected_tag(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = json.loads(self.output.read_text())
        self.assertEqual(pin["antigravity"], expected_antigravity())
        self.assertEqual(
            pin["antigravity"]["x86_64-linux"]["hash"],
            "sha256-" + base64.b64encode(bytes.fromhex(AGY_PLATFORMS["linux-x64"][2])).decode(),
        )

    def test_source_is_fetched_at_the_selected_tag(self):
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.fetched_urls(),
            [
                DEFAULT_LIST_URL,
                f"https://raw.githubusercontent.com/pingdotgg/t3code/{NEWEST}/{AGY_SOURCE_PATH}",
            ],
        )

    def test_refuses_a_source_missing_a_required_platform(self):
        for key in AGY_PLATFORMS:
            with self.subTest(missing=key):
                result = self.run_release(
                    source=agy_source(omit=(key,)), extra_args=["-o", str(self.output)]
                )
                self.assert_refused(result, key)

    def test_refuses_a_malformed_runtime_sha256(self):
        good = AGY_PLATFORMS["linux-arm64"][2]
        for sha256 in [good.upper(), good[:-1], good + "0", "", "sha256:" + good]:
            with self.subTest(sha256=sha256):
                result = self.run_release(
                    source=agy_source(sha256s={"linux-arm64": sha256}),
                    extra_args=["-o", str(self.output)],
                )
                self.assert_refused(result, "sha256")

    def test_refuses_an_unparsable_source(self):
        no_version = agy_source().replace(
            f'const ANTIGRAVITY_RELEASE_VERSION = "{AGY_VERSION}";', ""
        )
        for source in ["", "<html>404: Not Found</html>", no_version]:
            with self.subTest(source=source[:40]):
                result = self.run_release(source=source, extra_args=["-o", str(self.output)])
                self.assert_refused(result, "antigravityRelease.ts")

    def test_empty_fetch_command_fails(self):
        result = self.run_release(fetch="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("T3CODE_RELEASE_FETCH is empty", result.stderr)


if __name__ == "__main__":
    unittest.main()
