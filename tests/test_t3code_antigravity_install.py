"""Drive t3code-antigravity-install against fake T3 Code base directories.

The runtime is a fake package directory holding two small files whose sizes
the fake pin records, so the tests check the layout T3 Code reads without the
real 400 MB runtime: active.json naming the release, and a version directory
holding .install-complete.json and the two binaries.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/t3code-antigravity-install"

SHA = "7cd97045f7b4fe81175a107cdf16f9c51484e3c78a5162cae415338bb6aa5b88"
OTHER_SHA = "bb23956b89984bf5d354af2c3725e6c57f0cc1b7228e77a0e91c9c2bc1d47646"
PLATFORM = "darwin-arm64"
EXECUTABLE = b"#!/bin/sh\necho acp\n"
HARNESS = b"#!/bin/sh\necho harness server\n"

PIN = {
    "platform": PLATFORM,
    "version": "1.3.0",
    "url": "https://dl.google.com/agy-extensions/releases/macos/agy-acp-server-1.3.0-darwin-arm64.zip",
    "sha256": SHA,
    "hash": "sha256-fNlwRfe0/oEXWhB6/2/lzpkb64SyVMu8dx0q5su6WIs=",
    "archiveBytes": 111456962,
    "executable": {"name": "agy_acp_server.par", "bytes": len(EXECUTABLE)},
    "harness": {"name": "localharness_external", "bytes": len(HARNESS)},
}

# The record T3 Code's installer writes and its resolver checks.
RECORD = {
    "releaseId": SHA,
    "version": "1.3.0",
    "executable": {"name": "agy_acp_server.par", "bytes": len(EXECUTABLE)},
    "harness": {"name": "localharness_external", "bytes": len(HARNESS)},
}


def make_runtime(root, name):
    runtime = Path(root) / name
    runtime.mkdir()
    for file, content in (
        ("agy_acp_server.par", EXECUTABLE),
        ("localharness_external", HARNESS),
    ):
        path = runtime / file
        path.write_bytes(content)
        path.chmod(0o555)
    return runtime


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.base = self.root / "home/.t3"
        self.runtime = make_runtime(self.root, "package")
        self.pin = self.root / "pin.json"
        self.pin.write_text(json.dumps(PIN))
        self.managed = self.base / "tools/antigravity-acp" / PLATFORM
        self.version_dir = self.managed / "versions" / SHA

    def tearDown(self):
        self.tmp.cleanup()

    def run_installer(self, runtime=None):
        result = subprocess.run(
            [
                str(SCRIPT),
                "--base-dir",
                str(self.base),
                "--runtime",
                str(runtime or self.runtime),
                "--pin",
                str(self.pin),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def active(self):
        return json.loads((self.managed / "active.json").read_text())

    def record(self):
        return json.loads((self.version_dir / ".install-complete.json").read_text())

    def assert_linked_to(self, runtime):
        for name in ("agy_acp_server.par", "localharness_external"):
            path = self.version_dir / name
            self.assertTrue(path.is_symlink(), f"{name} is not a symlink")
            self.assertEqual(Path(os.readlink(path)), runtime / name)

    def test_empty_base_gets_a_complete_managed_install(self):
        self.run_installer()
        self.assertEqual(self.active(), {"releaseId": SHA})
        self.assertEqual(self.record(), RECORD)
        self.assertFalse(self.version_dir.is_symlink())
        self.assert_linked_to(self.runtime)
        for path in (self.managed / "active.json", self.version_dir / ".install-complete.json"):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        # T3 Code checks each binary through stat, which follows the links.
        self.assertEqual(
            (self.version_dir / "agy_acp_server.par").stat().st_size, len(EXECUTABLE)
        )

    def test_second_run_changes_nothing(self):
        self.run_installer()
        inode = self.version_dir.stat().st_ino
        record_mtime = (self.version_dir / ".install-complete.json").stat().st_mtime_ns
        active_mtime = (self.managed / "active.json").stat().st_mtime_ns
        self.run_installer()
        self.assertEqual(self.version_dir.stat().st_ino, inode)
        self.assertEqual(
            (self.version_dir / ".install-complete.json").stat().st_mtime_ns, record_mtime
        )
        self.assertEqual((self.managed / "active.json").stat().st_mtime_ns, active_mtime)

    def test_t3_installed_release_with_real_binaries_is_left_alone(self):
        self.version_dir.mkdir(parents=True)
        for name, content in (
            ("agy_acp_server.par", EXECUTABLE),
            ("localharness_external", HARNESS),
        ):
            path = self.version_dir / name
            path.write_bytes(content)
            path.chmod(0o755)
        (self.version_dir / ".install-complete.json").write_text(json.dumps(RECORD))
        inode = (self.version_dir / "agy_acp_server.par").stat().st_ino
        self.run_installer()
        self.assertFalse((self.version_dir / "agy_acp_server.par").is_symlink())
        self.assertEqual((self.version_dir / "agy_acp_server.par").stat().st_ino, inode)
        self.assertEqual(self.active(), {"releaseId": SHA})

    def test_active_release_is_repointed_and_other_versions_survive(self):
        other = self.managed / "versions" / OTHER_SHA
        other.mkdir(parents=True)
        (other / "marker").write_text("kept")
        (self.managed / "active.json").write_text(json.dumps({"releaseId": OTHER_SHA}))
        self.run_installer()
        self.assertEqual(self.active(), {"releaseId": SHA})
        self.assertEqual((other / "marker").read_text(), "kept")

    def test_version_directory_missing_its_record_is_replaced(self):
        self.version_dir.mkdir(parents=True)
        (self.version_dir / "agy_acp_server.par").write_bytes(b"partial")
        self.run_installer()
        self.assertEqual(self.record(), RECORD)
        self.assert_linked_to(self.runtime)

    def test_dangling_links_from_a_collected_package_are_replaced(self):
        gone = self.root / "collected"
        self.run_installer(runtime=make_runtime(self.root, "collected"))
        for name in ("agy_acp_server.par", "localharness_external"):
            (gone / name).chmod(0o755)
            (gone / name).unlink()
        gone.rmdir()
        self.run_installer()
        self.assert_linked_to(self.runtime)

    def test_links_to_an_older_live_package_are_replaced(self):
        older = make_runtime(self.root, "older")
        self.run_installer(runtime=older)
        self.assert_linked_to(older)
        self.run_installer()
        self.assert_linked_to(self.runtime)
        self.assertEqual(self.record(), RECORD)


if __name__ == "__main__":
    unittest.main(verbosity=2)
