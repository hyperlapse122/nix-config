"""Drive antigravity-acp-release against fake release endpoints.

The script's HEAD requests and downloads go through overridable commands, so
these tests serve fixture headers and fixture zips and record which URLs it
asked for.
"""

import base64
import hashlib
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/antigravity-acp-release"

BASE = "https://dl.google.com/agy-extensions/releases"
SYSTEMS = {
    "x86_64-linux": ("linux-x64", "linux", "linux-x86_64"),
    "aarch64-linux": ("linux-arm64", "linux", "linux-arm64"),
    "aarch64-darwin": ("darwin-arm64", "macos", "darwin-arm64"),
}
WINDOW_ABOVE_141 = "1.4.2-1.4.11, 1.5.0-1.5.10, 1.6.0-1.6.10, 1.7.0-1.7.10, 2.0.0-2.0.10"


def url(system, version):
    _, directory, suffix = SYSTEMS[system]
    return f"{BASE}/{directory}/agy-acp-server-{version}-{suffix}.zip"


FAKE_PROBE = """#!/usr/bin/env python3
import json, os, sys
url = sys.argv[-1]
with open(os.environ['FAKE_LOG'], 'a') as log:
    log.write('HEAD ' + url + '\\n')
served = json.loads(os.environ['FAKE_SERVED'])
if url in served:
    sys.stdout.write('HTTP/2 302\\r\\nlocation: x\\r\\n\\r\\nHTTP/2 200\\r\\ncontent-length: %d\\r\\n\\r\\n' % served[url]['length'])
else:
    sys.stdout.write('HTTP/2 404\\r\\ncontent-length: 1449\\r\\n\\r\\n')
"""

FAKE_DOWNLOAD = """#!/usr/bin/env python3
import json, os, shutil, sys
destination, url = sys.argv[-2], sys.argv[-1]
with open(os.environ['FAKE_LOG'], 'a') as log:
    log.write('GET ' + url + '\\n')
served = json.loads(os.environ['FAKE_SERVED'])
if url not in served:
    sys.exit(22)
shutil.copyfile(served[url]['file'], destination)
"""


class AntigravityAcpReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name, body in (("fake-probe", FAKE_PROBE), ("fake-download", FAKE_DOWNLOAD)):
            path = self.root / name
            path.write_text(body)
            path.chmod(0o755)
        self.log = self.root / "fetch.log"
        self.output = self.root / "antigravity-acp-release.json"
        self.served = {}

    def make_zip(self, name, members):
        path = self.root / name
        with zipfile.ZipFile(path, "w") as archive:
            for member, content in members.items():
                archive.writestr(member, content)
        return path

    def publish(self, version, systems=tuple(SYSTEMS), members=None, length_delta=0):
        """Serve version for the given systems; each archive's members differ per system."""
        for index, system in enumerate(systems):
            content = members or {
                "agy_acp_server.par": b"p" * (100 + index),
                "localharness_external": b"h" * (50 + index),
            }
            path = self.make_zip(f"{version}-{system}.zip", content)
            self.served[url(system, version)] = {
                "file": str(path),
                "length": path.stat().st_size + length_delta,
            }

    def pin(self, version):
        self.output.write_text(json.dumps({"version": version, "platforms": {}}) + "\n")

    def environment(self):
        env = dict(os.environ)
        env["AGY_ACP_RELEASE_PROBE"] = f"{sys.executable} {self.root / 'fake-probe'}"
        env["AGY_ACP_RELEASE_DOWNLOAD"] = f"{sys.executable} {self.root / 'fake-download'}"
        env["FAKE_LOG"] = str(self.log)
        env["FAKE_SERVED"] = json.dumps(self.served)
        return env

    def run_release(self, *extra):
        args = [sys.executable, str(SCRIPT), "--output", str(self.output), *extra]
        return subprocess.run(args, env=self.environment(), capture_output=True, text=True)

    def requests(self, method):
        if not self.log.exists():
            return []
        prefix = method + " "
        return [line[len(prefix):] for line in self.log.read_text().splitlines() if line.startswith(prefix)]

    def written(self):
        return json.loads(self.output.read_text())

    def assert_failed_keeping(self, result, version, message):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)
        self.assertEqual(self.written(), {"version": version, "platforms": {}})


class ResolvesTests(AntigravityAcpReleaseTestCase):
    def test_writes_every_system_from_the_downloaded_archive(self):
        self.pin("1.4.0")
        self.publish("1.4.1")
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = self.written()
        self.assertEqual(pin["version"], "1.4.1")
        self.assertEqual(sorted(pin["platforms"]), sorted(SYSTEMS))
        for index, system in enumerate(SYSTEMS):
            fixture = Path(self.served[url(system, "1.4.1")]["file"])
            digest = hashlib.sha256(fixture.read_bytes()).hexdigest()
            self.assertEqual(
                pin["platforms"][system],
                {
                    "platform": SYSTEMS[system][0],
                    "version": "1.4.1",
                    "url": url(system, "1.4.1"),
                    "sha256": digest,
                    "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode("ascii"),
                    "archiveBytes": fixture.stat().st_size,
                    "executable": {"name": "agy_acp_server.par", "bytes": 100 + index},
                    "harness": {"name": "localharness_external", "bytes": 50 + index},
                },
            )
        self.assertEqual(sorted(self.requests("GET")), sorted(url(s, "1.4.1") for s in SYSTEMS))

    def test_a_skipped_number_still_reaches_the_higher_release(self):
        self.pin("1.4.0")
        self.publish("1.4.1")
        self.publish("1.4.3")
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.written()["version"], "1.4.3")

    def test_a_release_one_system_lacks_falls_back_to_the_highest_complete_one(self):
        self.pin("1.4.0")
        self.publish("1.4.1")
        self.publish("1.5.0", systems=("x86_64-linux", "aarch64-darwin"))
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = self.written()
        self.assertEqual(pin["version"], "1.4.1")
        self.assertEqual({record["version"] for record in pin["platforms"].values()}, {"1.4.1"})
        self.assertNotIn(url("x86_64-linux", "1.5.0"), self.requests("GET"))

    def test_from_seeds_a_missing_pin(self):
        self.publish("1.4.1")
        result = self.run_release("--from", "1.3.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.written()["version"], "1.4.1")

    def test_dry_run_prints_the_pin_and_writes_nothing(self):
        self.pin("1.4.0")
        self.publish("1.4.1")
        result = self.run_release("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["version"], "1.4.1")
        self.assertEqual(self.written(), {"version": "1.4.0", "platforms": {}})


class NothingNewerTests(AntigravityAcpReleaseTestCase):
    def test_a_current_pin_downloads_nothing_and_names_the_window(self):
        self.pin("1.4.1")
        self.publish("1.3.0")
        self.publish("1.4.1")
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"no complete release newer than 1.4.1 within {WINDOW_ABOVE_141}", result.stdout)
        self.assertEqual(self.requests("GET"), [])
        self.assertEqual(self.written(), {"version": "1.4.1", "platforms": {}})

    def test_the_window_is_probed_highest_first(self):
        self.pin("1.4.1")
        self.run_release()
        heads = [line for line in self.requests("HEAD") if "linux-x86_64" in line]
        self.assertEqual(heads[0], url("x86_64-linux", "2.0.10"))
        self.assertEqual(heads[-1], url("x86_64-linux", "1.4.2"))
        self.assertEqual(len(heads), 10 + 3 * 11 + 11)

    def test_a_release_just_outside_the_window_is_not_selected(self):
        self.pin("1.4.1")
        for version in ("1.4.12", "1.8.0", "2.0.11", "2.1.0", "3.0.0"):
            self.publish(version)
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no complete release newer than 1.4.1", result.stdout)
        self.assertEqual(self.requests("GET"), [])
        self.assertEqual(self.written(), {"version": "1.4.1", "platforms": {}})


class RefusalTests(AntigravityAcpReleaseTestCase):
    def test_an_older_candidate_set_refuses_a_downgrade(self):
        self.pin("1.4.1")
        self.publish("1.3.0")
        result = self.run_release("--from", "1.2.0")
        self.assert_failed_keeping(result, "1.4.1", "refusing to downgrade")
        self.assertEqual(self.requests("GET"), [])

    def test_a_download_that_differs_from_its_head_length_fails(self):
        self.pin("1.4.0")
        self.publish("1.4.1", length_delta=1)
        result = self.run_release()
        self.assert_failed_keeping(result, "1.4.0", "not the")

    def test_an_archive_without_the_harness_fails(self):
        self.pin("1.4.0")
        self.publish("1.4.1", members={"agy_acp_server.par": b"p"})
        result = self.run_release()
        self.assert_failed_keeping(result, "1.4.0", "not exactly agy_acp_server.par and localharness_external")

    def test_an_archive_with_an_extra_member_fails(self):
        self.pin("1.4.0")
        self.publish(
            "1.4.1",
            members={"agy_acp_server.par": b"p", "localharness_external": b"h", "README": b"r"},
        )
        result = self.run_release()
        self.assert_failed_keeping(result, "1.4.0", "not exactly")

    def test_a_failed_head_request_fails_instead_of_reporting_nothing_newer(self):
        self.pin("1.4.1")
        env = self.environment()
        env["AGY_ACP_RELEASE_PROBE"] = "false"
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--output", str(self.output)], env=env, capture_output=True, text=True
        )
        self.assert_failed_keeping(result, "1.4.1", "failed with status 1")

    def test_a_failure_mid_write_leaves_the_old_pin_readable(self):
        self.pin("1.4.0")
        self.publish("1.4.1")
        loader = importlib.machinery.SourceFileLoader("antigravity_acp_release", str(SCRIPT))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        module = importlib.util.module_from_spec(spec)
        loader.exec_module(module)
        with mock.patch.dict(os.environ, self.environment()), mock.patch.object(
            module.os, "replace", side_effect=OSError("disk full")
        ):
            status = module.main(["--output", str(self.output)])
        self.assertEqual(status, 1)
        self.assertEqual(self.written(), {"version": "1.4.0", "platforms": {}})
        self.assertEqual(sorted(p.name for p in self.root.glob(".antigravity-acp-release.*")), [])


if __name__ == "__main__":
    unittest.main()
