---
title: Orca Android Emulator Support - Plan
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Orca Android Emulator Support - Plan

## Goal Capsule

- **Objective:** On both hosts, Orca's mobile emulator settings detect the Nix-provisioned Android SDK, so `orca emulator devices` and `orca emulator attach <avd>` can boot and drive an Android Virtual Device.
- **Means:** Pin the Android Emulator and one x86_64 system image alongside the existing SDK packages, build them into the same store SDK, and guard both with the existing checks (KTD1-KTD4).
- **Authority:** This plan, then `AGENTS.md`, then the conventions of `packages/android-sdk.nix`, `scripts/android-sdk-release`, and `tests/android-sdk.nix`.
- **Stop conditions:** Stop if the pinned emulator cannot run `-version` in the build sandbox after androidenv patches it, or if adding the system image breaks any host build.
- **Execution profile:** Nix packaging, a Ruby helper extension, Python and Nix checks, and docs. No hardware installation and no `nixos-rebuild switch`.
- **Finishes the work:** `ce-work` implements and verifies with the fast Nix commands. The user relaunches Orca after their own rebuild and runs the hardware checklist items.

---

## Product Contract

### Summary

Orca rejects the SDK today because it has no `emulator` directory. Add the emulator and a system image to the pinned SDK, so Orca accepts `ANDROID_HOME` and an AVD can be created and booted from the read-only store SDK.

### Problem Frame

Orca 1.4.206 shows "Android SDK not found. Install Android Studio and set ANDROID_HOME." in its mobile emulator settings. Its main-process detection (`Gqi`/`Kqi`/`Jqi` in `out/main/index.js`) tries `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then `~/Android/Sdk`. It accepts a root only when both `<root>/platform-tools/adb` and `<root>/emulator/emulator` exist. `home/h82/dev/android.nix` already exports both variables to login shells and to the systemd user manager, but `packages/android-sdk.nix` builds with `includeEmulator = false`, so `emulator/emulator` is missing and detection fails. Attaching also needs at least one AVD, and an AVD needs a system image. The SDK is a read-only store path, so `sdkmanager` cannot add one at run time.

### Requirements

- R1. On all four host configurations, `~/.local/share/android-sdk/emulator/emulator` exists, is executable, and runs.
- R2. On all four host configurations, the SDK carries the Google APIs x86_64 system image for every pinned platform API level, so `avdmanager create avd` can target it without network access.
- R3. `android-sdk-release` pins the emulator as a tracked package (newest stable) and pins the system images for the declared platforms. Its archive data comes from Google's repository XML, as it does for the existing packages.
- R4. The existing checks fail when R1 or R2 stops holding, and the parity check also covers the pinned system images.
- R5. The verification checklist tells the user how to create an AVD and confirm Orca detects the SDK.

### Scope Boundaries

- Declaratively creating AVDs is excluded. AVDs are mutable user state under `~/.android/avd`. The docs give the `avdmanager` command instead.
- A `cmdline-tools/latest` link is excluded. Orca derives `avdmanager` at that path but never invokes it; its only use of the path is building the result object.
- Other system image tags (`google_apis_playstore`, `default`) and ABIs (`arm64-v8a`) are excluded. Both hosts are x86_64.
- Pointing Orca at the SDK through its "SDK folder" setting is not needed. The environment variables already reach Orca once it is started after login.

### Sources

- Orca 1.4.206 `resources/app.asar`, `out/main/index.js`: SDK candidate order and the `adb` plus `emulator` existence test. `emulator -list-avds` resolves AVD names, and the emulator starts with `-no-window`.
- `orca skills get orca-emulator-android`: requires `adb` and `emulator` on the SDK path plus at least one AVD.
- nixpkgs `pkgs/development/mobile/androidenv`: `compose-android-packages.nix` takes `includeEmulator`, `emulatorVersion`, `includeSystemImages`, `systemImageTypes`, and `abiVersions`. It reads images from `repo.json` `images.<api>.<tag>.<abi>`. `update.rb` parses them from `sys-img/<tag>/sys-img2-3.xml` with `parse_image_xml` and `image_url`.
- nixpkgs `repo.json`: `images.36.google_apis.x86_64` is licensed `android-sdk-license`, about 1.9 GB. `emulator` 37.1.11 is licensed `android-sdk-license`.
- `/dev/kvm` is mode 0666 on this host, so the emulator gets hardware acceleration without group changes.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **The emulator is a tracked package.** Add `emulator` to `TRACKED` in `scripts/android-sdk-release`, so it follows the newest stable release with a `android-sdk-license` license, like `cmdline-tools` and `platform-tools`, including the refuse-to-downgrade rule. It is in the same `repository2-3.xml` the script already fetches, so no new fetch is needed. `packages/android-sdk.nix` sets `includeEmulator = true` and `emulatorVersion = repo.latest.emulator`.
- KTD2. **System images follow the declared platforms.** The helper pins the `google_apis` `x86_64` image for each declared platform API level. No separate version is declared, so bumping `--platforms` brings its image along. The helper refuses a declared platform whose image upstream does not list, matching its refusal to drop a declared version. The tag and ABI are constants in the script, like `TRACKED`.
- KTD3. **Vendor `image_url` and `parse_image_xml` verbatim from the same nixpkgs revision.** The vendored block already states its source revision and asks to stay verbatim. Extending it keeps the parity check meaningful. The image XML URL is derived from `--url`'s directory (`<dir>/sys-img/google_apis/sys-img2-3.xml`) so fixture tests can serve both documents through `ANDROID_SDK_RELEASE_FETCH`. Rendered `images` replace today's hard-coded empty object.
- KTD4. **Checks read the materialized SDK.** Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, `tests/android-sdk.nix` inspects the linked store SDK: each pinned image's `package.xml` at its repository path, and the emulator's own reported version against the pin. The expected values come from the pin file, not the module. The parity script extends its comparison to `images`.

### Assumptions

- The user wants a usable emulator, not only a green detection badge, so one system image per pinned platform is worth about 1.9 GB per host. The scoping confirmation was skipped because this runs autonomously; the image tag and ABI are recorded here for correction.
- `emulator -version` runs in the Nix build sandbox without a display or `/dev/kvm`. If it does not, the check falls back to asserting the executable and the emulator's `package.xml` revision, and the plan's stop condition does not fire.
- The running Orca process started before `ANDROID_HOME` reached the systemd user environment. Orca needs a relaunch after the rebuild; no configuration change handles that.

---

## Implementation Units

### U1. Pin the emulator and system images in the release helper

**Goal:** `android-sdk-release` writes a pin that carries the emulator and the declared platforms' system images.

**Requirements:** R3

**Dependencies:** None

**Files:**

- `scripts/android-sdk-release`
- `tests/test_android_sdk_release.py`
- `packages/android-sdk-repo.json` (regenerated)

**Approach:**

1. Add `emulator` to `TRACKED` per KTD1.
2. Extend the vendored block with `image_url` and `parse_image_xml` from the stated nixpkgs revision, verbatim, per KTD3.
3. Fetch the `google_apis` image XML beside `--url`, parse it with the same strict parsing as the main XML, and keep the `x86_64` entries for the selected platform API levels, minus `last-available-day`.
4. Refuse when a selected platform has no matching image. Merge the image licenses into the license set `render` already checks.
5. Render the selected images into `images`, and add `emulator` to `latest`.
6. Regenerate `packages/android-sdk-repo.json` with the helper against Google's live XML. Keep the pinned build-tools and platforms unchanged.

**Patterns to follow:** The existing `TRACKED`/`DECLARED` selection, `render`'s license check, and the fixture-serving `ANDROID_SDK_RELEASE_FETCH` in the tests.

**Test scenarios:**

- The fixture repository gains stable and preview emulator releases; the pin tracks the newest stable one.
- The fixture image XML lists `x86_64` and `arm64-v8a` images for the declared platform and another API level; the pin holds only the declared platform's `x86_64` image, with the androidenv entry shape (`name`, `path`, `revision`, `archives`, `license`, `dependencies`).
- A declared platform with no image in the fixture: the helper exits non-zero and writes nothing.
- A newer pinned emulator than upstream's newest stable: the helper refuses to downgrade.
- Malformed image XML is refused.

**Verification:** `nix build --no-link .#checks.x86_64-linux.android-sdk-release` passes, and a mutation that drops the image filter or the emulator from `TRACKED` turns it red.

### U2. Build the emulator and system image into the SDK

**Goal:** The store SDK behind `~/.local/share/android-sdk` contains `emulator/` and `system-images/android-<api>/google_apis/x86_64/`.

**Requirements:** R1, R2

**Dependencies:** U1

**Files:**

- `packages/android-sdk.nix`

**Approach:** Set `includeEmulator = true`, `emulatorVersion = repo.latest.emulator`, `includeSystemImages = true`, `systemImageTypes = [ "google_apis" ]`, and `abiVersions = [ "x86_64" ]` per KTD1 and KTD2. The existing `platformVersions` selects the image API levels. Update the comment block if it names what is excluded.

**Test scenarios:** Covered by U3.

**Verification:** All four host toplevels build. The linked SDK contains `emulator/emulator` and the image's `package.xml`.

### U3. Extend the SDK and parity checks

**Goal:** The registered checks fail when the emulator or a pinned image goes missing, and parity covers images.

**Requirements:** R4

**Dependencies:** U2

**Files:**

- `tests/android-sdk.nix`
- `tests/android-sdk-repo-parity.py`

**Approach:**

1. In `tests/android-sdk.nix`, add the pin's images to the `package.xml` loop, so each image is checked at its repository path. Assert `emulator/emulator` is executable and that `emulator -version` reports `repo.latest.emulator`, per KTD4. This mirrors Orca's detection predicate: `platform-tools/adb` and `emulator/emulator` both present under the linked root. Update the header comment.
2. In the parity script, compare `images` entries against nixpkgs `repo.json` the same way as packages, skipping ones nixpkgs lacks.

**Execution note:** Read the check solution docs `AGENTS.md` lists before trusting the new assertions, and mutation-test them. Guard derivation interpolations per `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.

**Test scenarios:**

- Unmutated tree: `android-sdk` and `android-sdk-repo-parity` pass.
- `includeEmulator = false`: `android-sdk` fails on all four configurations naming `emulator`.
- `includeSystemImages = false`: `android-sdk` fails naming the image's `package.xml`.
- Change one field of the pinned image entry: parity fails naming that image.

**Verification:** `nix flake check` passes; each mutation above turns the named check red.

### U4. Document AVD creation and the Orca check

**Goal:** The user can create an AVD and confirm Orca's detection after rebuilding.

**Requirements:** R5

**Dependencies:** U2

**Files:**

- `docs/verification.md`

**Approach:** Beside the existing Android items, add a checklist item: after rebuild, relaunch Orca and confirm the mobile emulator settings show the Android SDK as available. Add a second item: create an AVD with `avdmanager create avd -n <name> -k "system-images;android-<api>;google_apis;x86_64"`, then run `orca emulator attach <name> --json` and confirm the device view appears. Note that a platform bump leaves existing AVDs pointing at an image the new pin may lack.

**Test scenarios:** Test expectation: none -- documentation only.

**Verification:** The items name the exact commands and the pinned API level.

---

## Verification

- `nix fmt -- --ci`
- `nix flake check`
- The four host builds `AGENTS.md` lists.
- Hardware evidence (user, after rebuild): Orca shows the Android SDK as available, and an AVD boots into Orca's emulator pane. Report it separately from VM and check evidence.
