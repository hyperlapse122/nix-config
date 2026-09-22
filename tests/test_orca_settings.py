#!/usr/bin/env python3
"""Tests for scripts/orca-settings-reconcile."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "orca-settings-reconcile"


class OrcaSettingsReconcileTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
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

    def tearDown(self):
        self.temp_dir.cleanup()

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
        """AE1: When Orca has never run, missing index exits with code 0 and no writes."""
        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)
        self.assertIn("missing", result.stderr.lower())
        self.assertFalse((self.config_dir / "profiles").exists())

    def test_stopped_orca_converges_declared_leaves(self):
        """AE3: When Orca is stopped, declared leaves are updated while unmanaged state is kept."""
        profile_dir = self.config_dir / "profiles" / "default-profile"
        profile_dir.mkdir(parents=True)
        (self.config_dir / "orca-profile-index.json").write_text(
            json.dumps({"activeProfileId": "default-profile"})
        )

        data_file = profile_dir / "orca-data.json"
        initial_data = {
            "settings": {
                "workspaceDir": "/tmp/old",
                "appFontFamily": "OldFont",
                "unmanagedSetting": "keep-me",
            },
            "worktreeMeta": {"project-a": {"path": "/worktrees/a"}},
            "telemetry": {"sessionId": 12345},
        }
        data_file.write_text(json.dumps(initial_data))

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)

        updated_data = json.loads(data_file.read_text())
        # Declared leaves updated
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

        # Unmanaged state preserved
        self.assertEqual(updated_data["settings"]["unmanagedSetting"], "keep-me")
        self.assertEqual(
            updated_data["worktreeMeta"]["project-a"]["path"],
            "/worktrees/a",
        )
        self.assertEqual(updated_data["telemetry"]["sessionId"], 12345)

    def test_active_singleton_lock_prevents_write(self):
        """AE2: When Orca is running (live PID on current host), reconciler logs and skips write."""
        profile_dir = self.config_dir / "profiles" / "default-profile"
        profile_dir.mkdir(parents=True)
        (self.config_dir / "orca-profile-index.json").write_text(
            json.dumps({"activeProfileId": "default-profile"})
        )

        data_file = profile_dir / "orca-data.json"
        initial_data = {"settings": {"workspaceDir": "/tmp/active-session"}}
        data_file.write_text(json.dumps(initial_data))

        # Create SingletonLock pointing to current process (which is alive)
        current_pid = os.getpid()
        hostname = os.uname().nodename
        lock_path = self.config_dir / "SingletonLock"
        lock_path.symlink_to(f"{hostname}-{current_pid}")

        result = self.run_reconciler(mode="assert")
        self.assertEqual(result.returncode, 0)
        self.assertIn("running", result.stderr.lower())

        # File was NOT modified
        current_data = json.loads(data_file.read_text())
        self.assertEqual(current_data["settings"]["workspaceDir"], "/tmp/active-session")

    def test_stale_singleton_lock_dead_pid_allows_write(self):
        """Stale lock from dead PID is treated as not running and allows assertion."""
        profile_dir = self.config_dir / "profiles" / "default-profile"
        profile_dir.mkdir(parents=True)
        (self.config_dir / "orca-profile-index.json").write_text(
            json.dumps({"activeProfileId": "default-profile"})
        )

        data_file = profile_dir / "orca-data.json"
        initial_data = {"settings": {"workspaceDir": "/tmp/stale"}}
        data_file.write_text(json.dumps(initial_data))

        # A very high PID unlikely to exist
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

    def test_report_mode_does_not_modify_file(self):
        """Report mode outputs drift without writing changes."""
        profile_dir = self.config_dir / "profiles" / "default-profile"
        profile_dir.mkdir(parents=True)
        (self.config_dir / "orca-profile-index.json").write_text(
            json.dumps({"activeProfileId": "default-profile"})
        )

        data_file = profile_dir / "orca-data.json"
        initial_data = {"settings": {"workspaceDir": "/tmp/before-report"}}
        data_file.write_text(json.dumps(initial_data))

        result = self.run_reconciler(mode="report")
        self.assertEqual(result.returncode, 0)
        self.assertIn("drift", result.stdout.lower())

        current_data = json.loads(data_file.read_text())
        self.assertEqual(current_data["settings"]["workspaceDir"], "/tmp/before-report")


if __name__ == "__main__":
    unittest.main()
