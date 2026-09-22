#!/usr/bin/env python3
"""Tests for scripts/orca-settings-reconcile."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "orca-settings-reconcile"


class OrcaSettingsReconcileTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.config_dir = Path(self.temp_dir.name) / "orca"
        self.config_dir.mkdir(parents=True)
        self.declared_file = Path(self.temp_dir.name) / "declared.json"

        self.declared_settings = {
            "settings.workspaceDir": "/home/h82/.local/share/worktrees",
            "settings.appFontFamily": "Pretendard",
            "settings.editorFontFamily": "JetBrainsMono NF",
            "settings.terminalFontFamily": "JetBrainsMono NF",
            "settings.defaultTuiAgent": "claude",
            "settings.voice.enabled": True,
            "settings.disabledTuiAgents": ["claude-agent-teams"],
        }
        self.declared_file.write_text(json.dumps(self.declared_settings))

    def _create_profile(self, initial_data, profile_id="default-profile"):
        profile_dir = self.config_dir / "profiles" / profile_id
        profile_dir.mkdir(parents=True, exist_ok=True)
        (self.config_dir / "orca-profile-index.json").write_text(
            json.dumps({"activeProfileId": profile_id})
        )
        data_file = profile_dir / "orca-data.json"
        if isinstance(initial_data, str):
            data_file.write_text(initial_data)
        else:
            data_file.write_text(json.dumps(initial_data))
        return data_file

    def run_reconciler(self, mode="assert"):
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--mode",
                mode,
                "--config-dir",
                str(self.config_dir),
                "--declared",
                str(self.declared_file),
            ],
            capture_output=True,
            text=True,
        )

    def test_missing_profile_index_exits_cleanly(self):
        """When Orca has never run, missing index exits with code 0 and no writes."""
        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)
        self.assertIn("missing", result.stderr.lower())
        self.assertFalse((self.config_dir / "profiles").exists())

    def test_stopped_orca_converges_declared_leaves(self):
        """When Orca is stopped, declared leaves are updated while unmanaged state is kept."""
        initial_data = {
            "settings": {
                "workspaceDir": "/tmp/old",
                "appFontFamily": "OldFont",
                "unmanagedSetting": "keep-me",
            },
            "worktreeMeta": {"project-a": {"path": "/worktrees/a"}},
            "telemetry": {"sessionId": 12345},
        }
        data_file = self._create_profile(initial_data)

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)

        updated_data = json.loads(data_file.read_text())
        self.assertEqual(
            updated_data["settings"]["workspaceDir"],
            "/home/h82/.local/share/worktrees",
        )
        self.assertEqual(updated_data["settings"]["appFontFamily"], "Pretendard")
        self.assertEqual(updated_data["settings"]["editorFontFamily"], "JetBrainsMono NF")
        self.assertEqual(updated_data["settings"]["voice"]["enabled"], True)
        self.assertEqual(
            updated_data["settings"]["disabledTuiAgents"],
            ["claude-agent-teams"],
        )

        self.assertEqual(updated_data["settings"]["unmanagedSetting"], "keep-me")
        self.assertEqual(
            updated_data["worktreeMeta"]["project-a"]["path"],
            "/worktrees/a",
        )
        self.assertEqual(updated_data["telemetry"]["sessionId"], 12345)

    def test_active_singleton_lock_prevents_write(self):
        """When Orca is running (live PID on current host), reconciler logs and skips write."""
        initial_data = {"settings": {"workspaceDir": "/tmp/active-session"}}
        data_file = self._create_profile(initial_data)

        # Spawn a dummy process whose cmdline clearly contains 'orca'
        proc = subprocess.Popen([sys.executable, "-c", "# orca-dummy\nimport time; time.sleep(10)"])
        self.addCleanup(lambda: (proc.terminate(), proc.wait()))

        hostname = os.uname().nodename
        lock_path = self.config_dir / "SingletonLock"
        lock_path.symlink_to(f"{hostname}-{proc.pid}")

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)
        self.assertIn("running", result.stderr.lower())

        current_data = json.loads(data_file.read_text())
        self.assertEqual(current_data["settings"]["workspaceDir"], "/tmp/active-session")

    def test_recycled_pid_dead_orca_allows_write(self):
        """Recycled PID from a different daemon is detected via /proc/cmdline and allows write."""
        initial_data = {"settings": {"workspaceDir": "/tmp/recycled"}}
        data_file = self._create_profile(initial_data)

        # Spawn a process whose cmdline definitely does NOT contain 'orca'
        proc = subprocess.Popen([sys.executable, "-c", "# dbus-dummy-daemon\nimport time; time.sleep(10)"])
        self.addCleanup(lambda: (proc.terminate(), proc.wait()))

        hostname = os.uname().nodename
        lock_path = self.config_dir / "SingletonLock"
        lock_path.symlink_to(f"{hostname}-{proc.pid}")

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)

        updated_data = json.loads(data_file.read_text())
        self.assertEqual(
            updated_data["settings"]["workspaceDir"],
            "/home/h82/.local/share/worktrees",
        )

    def test_stale_singleton_lock_dead_pid_allows_write(self):
        """Stale lock from dead PID is treated as not running and allows assertion."""
        initial_data = {"settings": {"workspaceDir": "/tmp/stale"}}
        data_file = self._create_profile(initial_data)

        dead_pid = 9999999
        hostname = os.uname().nodename
        lock_path = self.config_dir / "SingletonLock"
        lock_path.symlink_to(f"{hostname}-{dead_pid}")

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)

        updated_data = json.loads(data_file.read_text())
        self.assertEqual(
            updated_data["settings"]["workspaceDir"],
            "/home/h82/.local/share/worktrees",
        )

    def test_corrupted_data_file_logs_warning_and_exits_cleanly(self):
        """Corrupted JSON in orca-data.json logs warning and exits 0 instead of breaking rebuilds."""
        data_file = self._create_profile("corrupted { invalid json")

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)
        self.assertIn("failed to parse", result.stderr.lower())

    def test_report_mode_does_not_modify_file(self):
        """Report mode outputs drift without writing changes."""
        initial_data = {"settings": {"workspaceDir": "/tmp/before-report"}}
        data_file = self._create_profile(initial_data)

        result = self.run_reconciler(mode="report")
        self.assertEqual(result.returncode, 0)
        self.assertIn("drift", result.stdout.lower())

        current_data = json.loads(data_file.read_text())
        self.assertEqual(current_data["settings"]["workspaceDir"], "/tmp/before-report")


if __name__ == "__main__":
    unittest.main()
