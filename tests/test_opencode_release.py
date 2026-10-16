"""Drive opencode-release against fake npm registry fixtures.

The helper's network calls go through an overridable command, so these tests
feed it a fixture body per URL instead of making network calls.
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

BASE = "https://registry.npmjs.org"
VERSION = "2.0.31"
PACKAGES = {
    "x86_64-linux": "@opencode/cli-linux-x64",
    "aarch64-linux": "@opencode/cli-linux-arm64",
    "aarch64-darwin": "@opencode/cli-darwin-arm64",
}
INTEGRITY = {
    "@opencode/cli-linux-x64": "sha512-RYbqR/HzKTH9OSh98VOt78bgQ8sgidUCCCKR9CABSc06AFxZdycezIg8dUmh+uBdp2mf4ckWVq9BbGblbxtFZQ==",
    "@opencode/cli-linux-arm64": "sha512-LGAcODO4N9L+508pfVolMxPapGw+O3VG/Jo+1VlbuLC+RDH7IIX6Hi1bw5ofD4cfsC+zIJuZ/NF7cHPNSvH0mw==",
    "@opencode/cli-darwin-arm64": "sha512-NMRKzz9CO4DKOOZzPn5JZRBMdjN+qQj7CG5tg5xkq+uyrBYwF1P/n/0KMjKbjPOOxTLXk9K856Qi5z+b1uHMeg==",
}


def tarball(package, version=VERSION, host=BASE):
    short = package.split("/")[1]
    return f"{host}/{package}/-/{short}-{version}.tgz"


def latest_url(base=BASE):
    return f"{base}/@opencode/cli/latest"


def platform_url(package, version=VERSION, base=BASE):
    return f"{base}/{package}/{version}"


def platform_manifest(package, version=VERSION):
    return {
        "name": package,
        "version": version,
        "dist": {
            "integrity": INTEGRITY[package],
            "tarball": tarball(package, version),
        },
    }


def registry(version=VERSION, base=BASE):
    """Build a URL -> manifest map shaped like the npm registry's responses."""
    routes = {
        latest_url(base): {
            "name": "@opencode/cli",
            "version": version,
            "optionalDependencies": {package: version for package in PACKAGES.values()},
        }
    }
    for package in PACKAGES.values():
        routes[platform_url(package, version, base)] = platform_manifest(package, version)
    return routes


def pin(version=VERSION):
    return {
        "version": version,
        "platforms": {
            system: {
                "package": package,
                "url": tarball(package, version),
                "hash": INTEGRITY[package],
            }
            for system, package in PACKAGES.items()
        },
    }


FAKE_FETCH = """#!/usr/bin/env python3
import json, os, sys
status = int(os.environ.get('FAKE_STATUS', '0'))
if status:
    sys.exit(status)
routes = json.loads(os.environ.get('FAKE_ROUTES', '{}'))
body = routes.get(sys.argv[-1])
if body is None:
    sys.exit(22)
sys.stdout.write(body if isinstance(body, str) else json.dumps(body))
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

    def run_release(self, routes=None, extra_args=None, status=0, fetch=None):
        env = dict(os.environ)
        env["OPENCODE_RELEASE_FETCH"] = (
            f"{sys.executable} {self.fetch}" if fetch is None else fetch
        )
        env["FAKE_ROUTES"] = json.dumps(registry() if routes is None else routes)
        env["FAKE_STATUS"] = str(status)
        args = [sys.executable, str(SCRIPT)]
        args.extend(extra_args if extra_args is not None else ["--dry-run"])
        return subprocess.run(args, capture_output=True, text=True, env=env)

    def write_pin(self, version):
        self.output.write_text(json.dumps({"version": version, "platforms": {}}))

    def write_github_pin(self):
        self.output.write_text(
            json.dumps(
                {
                    "version": "1.19.3",
                    "platforms": {
                        "x86_64-linux": {
                            "asset": "opencode-linux-x64.tar.gz",
                            "sha256": "13a8fb2978302071b86f9d7e00da9c8895f9cd846978379c3bdc6a5333536c9b",
                            "hash": "sha256-E6j7KXgwIHG4b51+ANqciJX5zYRpeDecO9xqUzNTbJs=",
                        }
                    },
                }
            )
        )

    def assert_refused(self, routes, needle):
        """Run against an existing older pin and expect a refusal that leaves it alone."""
        self.write_pin("2.0.0")
        before = self.output.read_bytes()
        result = self.run_release(routes=routes, extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("opencode-release:", result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertEqual(self.output.read_bytes(), before)

    def test_writes_version_package_url_and_integrity_verbatim(self):
        self.write_github_pin()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("updated", result.stdout)
        self.assertEqual(json.loads(self.output.read_text()), pin())

    def test_writes_a_pin_when_none_exists(self):
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text()), pin())

    def test_numeric_version_comparison_beats_lexical(self):
        self.write_pin("2.0.9")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], VERSION)

    def test_same_version_leaves_the_pin_byte_identical(self):
        self.write_pin(VERSION)
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_older_version_leaves_the_pin_byte_identical(self):
        self.write_pin("2.0.40")
        before = self.output.read_bytes()
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        self.assertEqual(self.output.read_bytes(), before)

    def test_malformed_existing_pin_is_treated_as_absent(self):
        self.output.write_text("{not json")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], VERSION)

    def test_unparseable_pinned_version_is_replaced(self):
        self.write_pin("garbage")
        result = self.run_release(extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())["version"], VERSION)

    def test_unwritable_output_path_fails_with_a_message(self):
        missing = Path(self.tmp.name) / "missing" / "opencode-release.json"
        result = self.run_release(extra_args=["-o", str(missing)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("opencode-release:", result.stderr)
        self.assertFalse(missing.exists())

    def test_source_url_sets_the_registry_base(self):
        base = "https://mirror.example/npm"
        routes = registry(base=base)
        # A mirror may serve tarballs from the real registry host.
        result = self.run_release(routes=routes, extra_args=["--dry-run", "--source-url", base])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), pin())

    def test_refuses_a_version_that_is_not_a_plain_release(self):
        for version in ["0.0.0-dev-19274", "2.1.0-beta.1"]:
            with self.subTest(version=version):
                self.assert_refused(registry(version=version), version)

    def test_refuses_a_deprecated_latest(self):
        routes = registry()
        routes[latest_url()]["deprecated"] = "use something else"
        self.assert_refused(routes, "deprecated")

    def test_refuses_a_deprecated_platform_package(self):
        for package in PACKAGES.values():
            with self.subTest(package=package):
                routes = registry()
                routes[platform_url(package)]["deprecated"] = "broken build"
                self.assert_refused(routes, "deprecated")

    def test_refuses_a_missing_or_mismatched_optional_dependency(self):
        missing = registry()
        del missing[latest_url()]["optionalDependencies"]["@opencode/cli-linux-arm64"]
        self.assert_refused(missing, "@opencode/cli-linux-arm64")

        other = registry()
        other[latest_url()]["optionalDependencies"]["@opencode/cli-linux-arm64"] = "2.0.30"
        self.assert_refused(other, "@opencode/cli-linux-arm64")

        absent = registry()
        del absent[latest_url()]["optionalDependencies"]
        self.assert_refused(absent, "@opencode/cli-linux-x64")

    def test_refuses_a_platform_manifest_for_another_version_or_name(self):
        package = "@opencode/cli-linux-x64"
        for field, value in [("version", "2.0.30"), ("name", "@opencode/cli-linux-arm64")]:
            with self.subTest(field=field):
                routes = registry()
                routes[platform_url(package)][field] = value
                self.assert_refused(routes, package)

    def test_refuses_integrity_that_is_not_a_single_sha512_digest(self):
        short = "sha512-" + base64.b64encode(b"x" * 63).decode("ascii")
        for integrity in [
            "sha1-" + base64.b64encode(b"x" * 20).decode("ascii"),
            short,
            INTEGRITY["@opencode/cli-linux-x64"] + " sha1-AAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "sha512-not base64!",
            None,
        ]:
            with self.subTest(integrity=integrity):
                routes = registry()
                routes[platform_url("@opencode/cli-linux-x64")]["dist"]["integrity"] = integrity
                self.assert_refused(routes, "integrity")

    def test_refuses_a_tarball_outside_the_npm_registry(self):
        for url in [
            "https://evil.example/x.tgz",
            "http://registry.npmjs.org/x.tgz",
            "https://registry.npmjs.org.evil.example/x.tgz",
            None,
        ]:
            with self.subTest(url=url):
                routes = registry()
                routes[platform_url("@opencode/cli-linux-x64")]["dist"]["tarball"] = url
                self.assert_refused(routes, "tarball")

    def test_refuses_a_body_that_is_not_json(self):
        for url in [latest_url(), platform_url("@opencode/cli-linux-x64")]:
            with self.subTest(url=url):
                routes = registry()
                routes[url] = "<html>bad gateway</html>"
                self.assert_refused(routes, "not JSON")

    def test_refuses_a_body_that_is_not_an_object(self):
        routes = registry()
        routes[latest_url()] = "[]"
        self.assert_refused(routes, "not a JSON object")

    def test_fetch_error_fails_naming_the_url(self):
        self.write_pin("2.0.0")
        before = self.output.read_bytes()
        result = self.run_release(status=22, extra_args=["-o", str(self.output)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("@opencode/cli/latest failed with status 22", result.stderr)
        self.assertEqual(self.output.read_bytes(), before)

    def test_dry_run_prints_json_and_writes_nothing(self):
        result = self.run_release(extra_args=["--dry-run", "-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), pin())
        self.assertFalse(self.output.exists())

    def test_empty_fetch_command_fails(self):
        result = self.run_release(fetch="")
        self.assertEqual(result.returncode, 1)
        self.assertIn("OPENCODE_RELEASE_FETCH is empty", result.stderr)


if __name__ == "__main__":
    unittest.main()
