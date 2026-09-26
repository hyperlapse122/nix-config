"""Drive the Ruby android-sdk-release against a fake repository2-3.xml.

The helper's network call goes through an overridable command, so these tests
serve a fixture repository instead. The fixture holds a stable and a preview
release of each tracked package, an obsolete duplicate revision, and a
`;latest` alias, which are the cases the selection rules have to tell apart.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# The flake check points ANDROID_SDK_RELEASE at the packaged helper; run
# directly, the tests drive the script with whatever ruby is on PATH.
SCRIPT = Path(__file__).resolve().parents[1] / "scripts/android-sdk-release"
COMMAND = (
    [os.environ["ANDROID_SDK_RELEASE"]]
    if os.environ.get("ANDROID_SDK_RELEASE")
    else ["ruby", str(SCRIPT)]
)


def generic(path, major, minor, micro, url, sha1, channel="channel-0", license_ref="android-sdk-license", host_os="linux"):
    host = f"<host-os>{host_os}</host-os>" if host_os else ""
    return f"""
  <remotePackage path="{path}">
    <type-details xsi:type="generic:genericDetailsType"/>
    <revision><major>{major}</major><minor>{minor}</minor><micro>{micro}</micro></revision>
    <display-name>{path} display</display-name>
    <uses-license ref="{license_ref}"/>
    <channelRef ref="{channel}"/>
    <archives>
      <archive>
        <complete><size>10</size><checksum type="sha1">{sha1}</checksum><url>{url}</url></complete>
        {host}
      </archive>
    </archives>
  </remotePackage>"""


def platform(api, major, url, sha1, obsolete=False):
    flag = ' obsolete="true"' if obsolete else ""
    return f"""
  <remotePackage path="platforms;android-{api}"{flag}>
    <type-details xsi:type="sdk:platformDetailsType">
      <api-level>{api}</api-level>
      <layoutlib api="15"/>
    </type-details>
    <revision><major>{major}</major></revision>
    <display-name>Android SDK Platform {api}</display-name>
    <uses-license ref="android-sdk-license"/>
    <channelRef ref="channel-0"/>
    <archives>
      <archive>
        <complete><size>20</size><checksum type="sha1">{sha1}</checksum><url>{url}</url></complete>
      </archive>
    </archives>
  </remotePackage>"""


def repository(*packages):
    return f"""<?xml version="1.0" encoding="utf-8"?>
<sdk:sdk-repository xmlns:sdk="http://schemas.android.com/sdk/android/repo/repository2/03"
    xmlns:generic="http://schemas.android.com/repository/android/generic/02"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <license id="android-sdk-license" type="text">Terms
and Conditions

Second  paragraph.</license>
  <license id="android-sdk-preview-license" type="text">Preview terms</license>
  <channel id="channel-0">stable</channel>
  <channel id="channel-1">beta</channel>
{''.join(packages)}
</sdk:sdk-repository>
"""


BASE = [
    generic("cmdline-tools;22.0", 22, 0, "", "cmdline-22.zip", "c22"),
    generic("cmdline-tools;23.0", 23, 0, "", "cmdline-23.zip", "c23"),
    generic("cmdline-tools;24.0", 24, 0, "", "cmdline-24.zip", "c24", channel="channel-1"),
    generic("cmdline-tools;latest", 99, 0, "", "cmdline-latest.zip", "cl"),
    generic("platform-tools", 37, 0, 1, "platform-tools_r37.0.1-linux.zip", "p3701"),
    generic("build-tools;36.0.0", 36, 0, 0, "build-tools_r36_linux.zip", "b36"),
    generic("build-tools;37.0.0", 37, 0, 0, "build-tools_r37_linux.zip", "b37"),
    platform(36, 2, "platform-36_r02.zip", "a36"),
    platform(34, 2, "platform-34_r02.zip", "a34r2"),
    platform(34, 3, "platform-34_r03.zip", "a34r3", obsolete=True),
]

FAKE_FETCH = """#!/usr/bin/env python3
import os, sys
status = int(os.environ.get('FAKE_STATUS', '0'))
if status:
    sys.exit(status)
sys.stdout.write(os.environ['FAKE_BODY'])
"""


class AndroidSdkReleaseTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.fetch = root / "fake-fetch"
        self.fetch.write_text(FAKE_FETCH)
        self.fetch.chmod(0o755)
        self.output = root / "android-sdk-repo.json"

    def run_release(self, args, body=None, status=0):
        env = dict(os.environ)
        env["ANDROID_SDK_RELEASE_FETCH"] = f"{sys.executable} {self.fetch}"
        env["FAKE_BODY"] = repository(*BASE) if body is None else body
        env["FAKE_STATUS"] = str(status)
        return subprocess.run(
            [*COMMAND, *args], capture_output=True, text=True, env=env
        )

    def write_pin(self, *extra):
        result = self.run_release(
            ["-o", str(self.output), "--build-tools", "36.0.0", "--platforms", "36", *extra]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.output.read_text())

    def test_tracks_newest_stable_and_keeps_declared_versions(self):
        pin = self.write_pin()
        self.assertEqual(
            pin["latest"],
            {
                "cmdline-tools": "23.0",
                "platform-tools": "37.0.1",
                "build-tools": "36.0.0",
                "platforms": "36",
            },
        )
        self.assertEqual(sorted(pin["packages"]["cmdline-tools"]), ["23.0"])
        self.assertEqual(sorted(pin["packages"]["build-tools"]), ["36.0.0"])
        self.assertEqual(sorted(pin["packages"]["platforms"]), ["36"])

    def test_renders_androidenv_entries(self):
        pin = self.write_pin()
        tools = pin["packages"]["platform-tools"]["37.0.1"]
        self.assertEqual(tools["path"], "platform-tools")
        self.assertEqual(tools["name"], "platform-tools")
        self.assertEqual(tools["license"], "android-sdk-license")
        self.assertEqual(tools["revision-details"], {"major:0": "37", "minor:1": "0", "micro:2": "1"})
        self.assertEqual(
            tools["type-details"], {"element-attributes": {"xsi:type": "ns5:genericDetailsType"}}
        )
        self.assertEqual(
            tools["archives"],
            [
                {
                    "arch": "all",
                    "os": "linux",
                    "sha1": "p3701",
                    "size": 10,
                    "url": "https://dl.google.com/android/repository/platform-tools_r37.0.1-linux.zip",
                }
            ],
        )
        platform36 = pin["packages"]["platforms"]["36"]
        self.assertEqual(platform36["path"], "platforms/android-36")
        self.assertEqual(
            platform36["type-details"],
            {
                "api-level:0": "36",
                "layoutlib:1": {"element-attributes": {"api": "15"}},
                "element-attributes": {"xsi:type": "ns11:platformDetailsType"},
            },
        )
        self.assertEqual(platform36["archives"][0]["os"], "all")

    def test_keeps_only_referenced_licenses_normalized(self):
        pin = self.write_pin()
        self.assertEqual(
            pin["licenses"], {"android-sdk-license": ["Terms and Conditions\n\nSecond paragraph."]}
        )

    def test_duplicate_revision_fills_obsolete_and_merges_archives(self):
        pin = self.write_pin("--platforms", "34")
        platform34 = pin["packages"]["platforms"]["34"]
        self.assertEqual(platform34["obsolete"], "true")
        self.assertEqual(platform34["revision-details"], {"major:0": "2"})
        self.assertEqual([a["sha1"] for a in platform34["archives"]], ["a34r3"])

    def test_later_run_keeps_declared_versions_from_the_pin(self):
        self.write_pin("--build-tools", "37.0.0")
        result = self.run_release(["-o", str(self.output)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already up to date", result.stdout)
        pin = json.loads(self.output.read_text())
        self.assertEqual(sorted(pin["packages"]["build-tools"]), ["36.0.0", "37.0.0"])
        self.assertEqual(pin["latest"]["build-tools"], "37.0.0")

    def test_bumps_a_tracked_package_when_upstream_moves(self):
        self.write_pin()
        newer = [p for p in BASE if "platform-tools" not in p] + [
            generic("platform-tools", 37, 0, 2, "platform-tools_r37.0.2-linux.zip", "p3702")
        ]
        result = self.run_release(["-o", str(self.output)], body=repository(*newer))
        self.assertEqual(result.returncode, 0, result.stderr)
        pin = json.loads(self.output.read_text())
        self.assertEqual(sorted(pin["packages"]["platform-tools"]), ["37.0.2"])
        self.assertEqual(pin["packages"]["platforms"]["36"]["archives"][0]["sha1"], "a36")

    def test_ignores_preview_licensed_release_on_stable_channel(self):
        extra = generic(
            "cmdline-tools;25.0", 25, 0, "", "cmdline-25.zip", "c25",
            license_ref="android-sdk-preview-license",
        )
        result = self.run_release(
            ["--dry-run", "--build-tools", "36.0.0", "--platforms", "36"],
            body=repository(*BASE, extra),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["latest"]["cmdline-tools"], "23.0")

    def test_refuses_to_downgrade_a_tracked_package(self):
        self.write_pin()
        before = self.output.read_text()
        older = [p for p in BASE if "platform-tools" not in p] + [
            generic("platform-tools", 36, 0, 0, "platform-tools_r36-linux.zip", "p36")
        ]
        result = self.run_release(["-o", str(self.output)], body=repository(*older))
        self.assertEqual(result.returncode, 1)
        self.assertIn("refusing to downgrade", result.stderr)
        self.assertEqual(self.output.read_text(), before)

    def test_refuses_to_drop_a_declared_version(self):
        self.write_pin()
        before = self.output.read_text()
        without = [p for p in BASE if "build-tools;36.0.0" not in p]
        result = self.run_release(["-o", str(self.output)], body=repository(*without))
        self.assertEqual(result.returncode, 1)
        self.assertIn("build-tools 36.0.0 is not in the upstream repository", result.stderr)
        self.assertEqual(self.output.read_text(), before)

    def test_requires_declared_versions_for_a_new_pin(self):
        result = self.run_release(["-o", str(self.output)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("pass --build-tools", result.stderr)
        self.assertFalse(self.output.exists())

    def test_fetch_failure_writes_nothing(self):
        result = self.run_release(["-o", str(self.output)], status=22)
        self.assertEqual(result.returncode, 1)
        self.assertIn("failed with status 22", result.stderr)
        self.assertFalse(self.output.exists())

    def test_malformed_xml_is_refused(self):
        result = self.run_release(["--dry-run"], body="<not-xml")
        self.assertEqual(result.returncode, 1)
        self.assertIn("did not parse", result.stderr)


if __name__ == "__main__":
    unittest.main()
