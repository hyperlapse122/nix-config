#!/usr/bin/env python3
"""Focused, secret-free tests for the user-mode age identity installer.

The installer places a host's recovered age identity at
~/.config/nix-config/age/key.txt on a non-NixOS host. Each test runs the real
script as a subprocess against a temporary HOME and a fake age-keygen, so no
real key or card is involved.
"""

import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/install-user-age-identity"
RECIPIENT = "age1testrecipient"


class InstallUserIdentityTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.home = Path(self.directory.name) / "home"
        self.home.mkdir()
        self.keygen = Path(self.directory.name) / "age-keygen"
        # Derives the fixed recipient only for the one valid payload.
        self.keygen.write_text(
            f"#!{sys.executable}\n"
            "import pathlib, sys\n"
            "data = pathlib.Path(sys.argv[2]).read_bytes()\n"
            "if data != b'VALID-ID\\n': raise SystemExit(1)\n"
            "print('age1testrecipient')\n"
        )
        self.keygen.chmod(0o755)
        self.target = self.home / ".config/nix-config/age/key.txt"

    def tearDown(self):
        self.directory.cleanup()

    def run_installer(self, payload, recipient=RECIPIENT):
        env = dict(os.environ, HOME=str(self.home), INSTALL_USER_AGE_KEYGEN=str(self.keygen))
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--recipient", recipient],
            input=payload,
            env=env,
            capture_output=True,
        )

    def test_installs_valid_identity_privately(self):
        result = self.run_installer(b"VALID-ID\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.target.read_bytes(), b"VALID-ID\n")
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.target.parent.stat().st_mode), 0o700)
        self.assertEqual(self.target.stat().st_uid, os.getuid())

    def test_refuses_recipient_mismatch_and_keeps_existing(self):
        self.target.parent.mkdir(parents=True, mode=0o700)
        self.target.write_bytes(b"OLD\n")
        result = self.run_installer(b"OTHER-ID\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"recipient mismatch", result.stderr)
        self.assertEqual(self.target.read_bytes(), b"OLD\n")

    def test_refuses_symlinked_target(self):
        self.target.parent.mkdir(parents=True, mode=0o700)
        elsewhere = Path(self.directory.name) / "elsewhere"
        elsewhere.write_bytes(b"UNTOUCHED\n")
        self.target.symlink_to(elsewhere)
        result = self.run_installer(b"VALID-ID\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(elsewhere.read_bytes(), b"UNTOUCHED\n")
        self.assertTrue(self.target.is_symlink())

    def test_refuses_symlinked_directory(self):
        real = Path(self.directory.name) / "real-age"
        real.mkdir(mode=0o700)
        (self.home / ".config/nix-config").mkdir(parents=True)
        (self.home / ".config/nix-config/age").symlink_to(real)
        result = self.run_installer(b"VALID-ID\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(real.iterdir()), [])

    def assert_refused_before_staging(self, result, message):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertFalse(self.target.exists())
        parent = self.target.parent
        if parent.exists():
            self.assertEqual([p.name for p in parent.iterdir()], [])

    def test_refuses_empty_identity(self):
        self.assert_refused_before_staging(self.run_installer(b""), b"empty or too large")

    def test_refuses_oversized_identity(self):
        self.assert_refused_before_staging(self.run_installer(b"x" * 8193), b"empty or too large")

    def test_refuses_identity_with_nul_bytes(self):
        self.assert_refused_before_staging(self.run_installer(b"VALID\x00ID\n"), b"NUL bytes")

    def test_refuses_invalid_recipient_argument(self):
        self.assert_refused_before_staging(
            self.run_installer(b"VALID-ID\n", recipient="not-a-recipient"), b"expected recipient is invalid"
        )

    def test_mismatch_leaves_no_staged_file(self):
        self.run_installer(b"OTHER-ID\n")
        self.assertEqual([p.name for p in self.target.parent.iterdir()], [])

    def test_never_prints_the_identity(self):
        result = self.run_installer(b"OTHER-ID\n")
        self.assertNotIn(b"OTHER-ID", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
