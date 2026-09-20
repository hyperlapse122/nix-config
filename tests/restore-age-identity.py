#!/usr/bin/env python3
"""Focused, secret-free tests for the fixed-path restore helper."""

import importlib.machinery
import importlib.util
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("restore_age_identity", str(ROOT / "scripts/restore-age-identity"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class RestoreIdentityTests(unittest.TestCase):
    recipient = "age1testrecipient"

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.target = self.root / "key.txt"
        self.keygen = self.root / "age-keygen"
        self.keygen.write_text(
            f"#!{sys.executable}\n"
            "import pathlib, sys\n"
            "data = pathlib.Path(sys.argv[2]).read_bytes()\n"
            "if data != b'VALID-ID': raise SystemExit(1)\n"
            "print('age1testrecipient')\n"
        )
        self.keygen.chmod(0o755)
        self.root_patch = mock.patch.object(MODULE, "_prepare_directory", return_value=True)
        self.chown_patch = mock.patch.object(MODULE.os, "chown", lambda path, uid, gid: None)
        self.root_patch.start()
        self.chown_patch.start()

    def tearDown(self):
        self.chown_patch.stop()
        self.root_patch.stop()
        self.directory.cleanup()

    def install(self, payload, expected=recipient):
        return MODULE.install_identity(
            payload,
            expected,
            target=str(self.target),
            age_keygen=str(self.keygen),
            uid=0,
        )

    def test_valid_identity_is_root_mode_0600_and_atomic_target(self):
        self.assertTrue(self.install(b"VALID-ID"))
        self.assertEqual(self.target.read_bytes(), b"VALID-ID")
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)

    def test_recipient_mismatch_preserves_existing_target(self):
        self.target.write_bytes(b"OLD")
        self.assertFalse(self.install(b"VALID-ID", expected="age1otherrecipient"))
        self.assertEqual(self.target.read_bytes(), b"OLD")

    def test_corrupt_identity_preserves_existing_target(self):
        self.target.write_bytes(b"OLD")
        self.assertFalse(self.install(b"CORRUPT"))
        self.assertEqual(self.target.read_bytes(), b"OLD")

    def test_empty_oversized_and_nul_inputs_are_rejected(self):
        self.target.write_bytes(b"OLD")
        for payload in (b"", b"x" * (MODULE.MAX_IDENTITY_BYTES + 1), b"VALID\x00ID"):
            self.assertFalse(self.install(payload))
            self.assertEqual(self.target.read_bytes(), b"OLD")

    def test_non_root_cannot_install(self):
        self.assertFalse(MODULE.install_identity(b"VALID-ID", self.recipient, target=str(self.target), age_keygen=str(self.keygen), uid=1000))

    def test_symlink_parent_is_rejected(self):
        real = self.root / "real"
        real.mkdir()
        link = self.root / "link"
        link.symlink_to(real, target_is_directory=True)
        self.root_patch.stop()
        try:
            self.assertFalse(MODULE.install_identity(b"VALID-ID", self.recipient, target=str(link / "key.txt"), age_keygen=str(self.keygen), uid=0))
        finally:
            self.root_patch.start()


if __name__ == "__main__":
    unittest.main()
