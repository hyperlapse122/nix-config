import importlib.machinery
import importlib.util
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/desktop-ssh"
loader = importlib.machinery.SourceFileLoader("desktop_ssh", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
desktop_ssh = importlib.util.module_from_spec(spec)
loader.exec_module(desktop_ssh)


class MemoryWallet:
    def __init__(self):
        self.entries = {}
        self.fail_write = False
        self.fail_readback = False

    def read(self, name):
        if self.fail_readback and name in self.entries:
            return "incorrect-readback"
        return self.entries.get(name)

    def write(self, name, value):
        if self.fail_write:
            raise desktop_ssh.DesktopSSHError("wallet write failed")
        self.entries[name] = value


class ProvisionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path.cwd())
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.key_file = self.root / ".ssh/id_ed25519_nix_config"
        self.source = self.root / "source"
        self.public = self.root / "source.pub"
        self.wallet = MemoryWallet()
        self.source_key = self.new_source()

    def new_source(self):
        key = Ed25519PrivateKey.generate()
        self.source.unlink(missing_ok=True)
        self.source.write_bytes(key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.OpenSSH,
            serialization.NoEncryption()))
        self.source.chmod(0o400)
        self.public.write_bytes(key.public_key().public_bytes(
            serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH))
        return key

    def provision(self):
        return desktop_ssh.provision(self.source, self.public, self.key_file, self.wallet)

    def assert_encrypted_identity(self, key):
        data = self.key_file.read_bytes()
        with self.assertRaises((ValueError, TypeError)):
            serialization.load_ssh_private_key(data, password=None)
        password = self.wallet.entries[desktop_ssh.fingerprint(key.public_key())]
        loaded = serialization.load_ssh_private_key(data, password=password.encode())
        self.assertEqual(desktop_ssh.public_bytes(loaded.public_key()),
                         desktop_ssh.public_bytes(key.public_key()))
        self.assertEqual(self.key_file.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.key_file.parent.stat().st_mode & 0o777, 0o700)

    def test_protected_key_and_unchanged_pair(self):
        self.assertTrue(self.provision())
        self.assert_encrypted_identity(self.source_key)
        before = self.key_file.read_bytes()
        inode = self.key_file.stat().st_ino
        entries = dict(self.wallet.entries)
        self.assertFalse(self.provision())
        self.assertEqual(self.key_file.read_bytes(), before)
        self.assertEqual(self.key_file.stat().st_ino, inode)
        self.assertEqual(self.wallet.entries, entries)

    def test_rotation_and_recovery_keep_source_identity(self):
        self.provision()
        old_entries = dict(self.wallet.entries)
        key = self.new_source()
        self.provision()
        self.assert_encrypted_identity(key)
        self.assertTrue(old_entries.items() <= self.wallet.entries.items())
        self.key_file.unlink()
        self.provision()
        self.assert_encrypted_identity(key)
        self.wallet.entries.clear()
        self.provision()
        self.assert_encrypted_identity(key)

    def test_concurrent_provisioning_retains_one_pair(self):
        with ThreadPoolExecutor(max_workers=2) as workers:
            results = list(workers.map(lambda _: self.provision(), range(2)))
        self.assertEqual(sorted(results), [False, True])
        self.assertEqual(len(self.wallet.entries), 1)
        self.assert_encrypted_identity(self.source_key)

    def test_loading_requires_matching_wallet_and_metadata(self):
        self.provision()
        declared = desktop_ssh.read_public_key(self.public)
        loaded = desktop_ssh.load_working_key(self.key_file, declared, self.wallet)
        self.assertEqual(desktop_ssh.public_bytes(loaded.public_key()),
                         desktop_ssh.public_bytes(self.source_key.public_key()))
        self.wallet.entries.clear()
        with self.assertRaisesRegex(desktop_ssh.DesktopSSHError, "missing from KWallet"):
            desktop_ssh.load_working_key(self.key_file, declared, self.wallet)

    def test_failures_preserve_usable_pair(self):
        self.provision()
        old_key = self.key_file.read_bytes()
        old_entries = dict(self.wallet.entries)
        self.new_source()
        self.wallet.fail_write = True
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.assertEqual(self.key_file.read_bytes(), old_key)
        self.assertEqual(self.wallet.entries, old_entries)
        self.wallet.fail_write = False
        self.wallet.fail_readback = True
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.assertEqual(self.key_file.read_bytes(), old_key)
        self.wallet.fail_readback = False
        with patch.object(desktop_ssh.os, "replace", side_effect=OSError("fake failure")):
            with self.assertRaises(OSError):
                self.provision()
        self.assertEqual(self.key_file.read_bytes(), old_key)
        self.assertTrue(old_entries.items() <= self.wallet.entries.items())
        self.assertEqual(sorted(p.name for p in self.key_file.parent.iterdir()),
                         [".desktop-ssh.lock", "id_ed25519_nix_config"])

    def test_mismatched_metadata_and_unsafe_files_rejected(self):
        self.provision()
        before = self.key_file.read_bytes()
        self.public.write_bytes(Ed25519PrivateKey.generate().public_key().public_bytes(
            serialization.Encoding.OpenSSH, serialization.PublicFormat.OpenSSH))
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.assertEqual(self.key_file.read_bytes(), before)
        self.public.write_bytes(desktop_ssh.public_bytes(self.source_key.public_key()))
        self.key_file.chmod(0o644)
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.key_file.chmod(0o600)
        self.key_file.unlink()
        outside = self.root / "outside"
        outside.write_text("do not replace")
        self.key_file.symlink_to(outside)
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.assertEqual(outside.read_text(), "do not replace")

    def test_symlink_parent_and_lock_rejected(self):
        outside = self.root / "outside"
        outside.mkdir(mode=0o700)
        self.key_file.parent.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()
        self.assertEqual(list(outside.iterdir()), [])
        self.key_file.parent.unlink()
        self.key_file.parent.mkdir(mode=0o700)
        (self.key_file.parent / ".desktop-ssh.lock").symlink_to(self.source)
        with self.assertRaises(desktop_ssh.DesktopSSHError):
            self.provision()

    def test_wallet_backend_error_does_not_expose_credentials(self):
        import dbus

        leaked_value = "FAKE-sensitive-backend-detail"
        with patch.object(dbus.bus, "BusConnection", side_effect=dbus.DBusException(leaked_value)):
            with self.assertRaises(desktop_ssh.DesktopSSHError) as error:
                desktop_ssh.KWallet()
        self.assertNotIn(leaked_value, str(error.exception))


if __name__ == "__main__":
    unittest.main()
