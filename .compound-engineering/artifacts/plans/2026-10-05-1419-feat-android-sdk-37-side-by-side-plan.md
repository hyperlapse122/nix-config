---
title: Android SDK 37 Side by Side with 36 - Plan
type: feat
date: 2026-10-05
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Android SDK 37 Side by Side with 36 - Plan

## Goal Capsule

- **Objective:** A project on any host that sets `compileSdk 36`, or `compileSdk 37` on AGP 9.1.1 or newer, builds against the read-only `~/.local/share/android-sdk` without downloading a platform, build-tools release, or system image, and an emulator AVD can be created for either API level.
- **Means:** Regenerate `packages/android-sdk-repo.json` with both API levels declared (KTD1, KTD2, KTD3), and make the `android-sdk` check hold both levels independently of the pin (KTD4).
- **Authority:** Issue #153 is the source of the request. Upstream repository XML decides package keys (KTD1 overrides the issue's literal `android-37` path).
- **Stop conditions:** Stop if upstream stops listing `platforms;android-37.0`, `build-tools;37.0.0`, or the `google_apis` x86_64 `37.0` image under `android-sdk-license`, or if the pinned emulator is older than the 37.0 image's minimum.
- **Execution profile:** Lightweight; configuration plus check changes. Proof is the built check and host builds, not new unit logic.
- **Finishing:** `ce-work` implements and verifies locally; the LFG pipeline reviews, ships the PR, and watches CI.

## Product Contract

### Summary

Pin Android platform `37.0`, build-tools `37.0.0`, and the `google_apis` x86_64 `37.0` system image beside the existing API 36 packages. Extend the `android-sdk` check so it fails when either API level's platform, build-tools, or image is missing from the materialized SDK.

### Problem Frame

The SDK is read-only, so a project whose `compileSdk` the pin lacks fails instead of downloading the platform (`docs/verification.md`). Today the pin carries only API 36, so any project that moved to API 37 cannot build on these hosts.

### Requirements

**SDK contents**

- R1. The materialized SDK holds `platforms/android-36` and `platforms/android-37.0`.
- R2. The materialized SDK holds `build-tools/36.0.0` and `build-tools/37.0.0`, and `aapt2` from each runs.
- R3. The materialized SDK holds `system-images/android-36/google_apis/x86_64` and `system-images/android-37.0/google_apis/x86_64`.

**Pin maintenance**

- R4. Re-running `android-sdk-release --output packages/android-sdk-repo.json` with no declared-version flags keeps both API levels declared.

**Verification**

- R5. The `android-sdk` check asserts both API levels from a list of its own, so dropping either level from the pin or from the module fails it.
- R6. `nix fmt -- --ci`, `nix flake check`, and every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output build.

### Scope Boundaries

- Platforms `37.1` and `37.2` are not pinned: they are minor API levels a project selects with `minorApiLevel`, and the issue asks for `compileSdk 37`.
- `build-tools` 36.1.0 is not added; API 36 keeps the pinned `36.0.0`.
- The release script's selection logic does not change; declared versions already survive a flagless run.
- Considered and not built: a release-script guard that refuses a declared platform or build-tools on a preview license. The script already refuses a declared platform without an image, the preview-licensed build-tools carry an `-rc` suffix nobody passes by accident, and the check in R5 fails before such a pin would reach a host. A preview-licensed release appearing under a declared version name would change the call.

## Planning Contract

### Key Technical Decisions

- KTD1. **Pin the platform as `37.0`, not `37`.** Upstream publishes API 37 only as `platforms;android-37.0` (plus the minor releases `37.1` and `37.2`); `--platforms 37` would be refused as absent upstream. AGP maps `compileSdk = 37` (minor level 0) to `android-37.0`, so this key is what a `compileSdk 37` project resolves. The image key is `37.0` as well (`system-images;android-37.0;google_apis;x86_64`, revision 6). Governs R1, R3.
- KTD2. **Pin build-tools `37.0.0`.** It is the newest 37.x release on `channel-0` under `android-sdk-license`; `37.0.0-rc1` and `-rc2` carry `android-sdk-preview-license`. Governs R2.
- KTD3. **Regenerate with `android-sdk-release`, passing every declared version of both repeated flags.** `--platforms` and `--build-tools` replace the declared set rather than append to it, so the run passes `--platforms 36 --platforms 37.0 --build-tools 36.0.0 --build-tools 37.0.0`. The run also refreshes the tracked packages (cmdline-tools, emulator, platform-tools) to the newest stable, as the scheduled `update-dependencies.yml` run would. Governs R1 to R4.
- KTD4. **The check carries its own list of required API levels and asserts on materialized paths.** Every existing assertion reads its expected versions from the pin, so removing a level from the pin also removes its assertions. A fixed list in `tests/android-sdk.nix` (platform key `36` with build-tools `36.0.0`, platform key `37.0` with build-tools `37.0.0`) asserts in the builder that `platforms/android-<key>`, `system-images/android-<key>/google_apis/x86_64`, and `build-tools/<version>` with a running `aapt2` exist under the SDK. Build-tools are named exactly, as R2 does, because a project that does not set `buildToolsVersion` gets AGP's default release, which the read-only SDK cannot download. Missing entries fail through `fail`, not through evaluation errors, so a mutation fails the build with a message rather than only breaking evaluation. Governs R5.
- KTD5. **`repo.latest` consumers need no change.** `latest.platforms` becomes `37.0` and `latest.build-tools` becomes `37.0.0`. Nothing in this repository reads either: `packages/android-sdk.nix` reads `latest` only for cmdline-tools, platform-tools, and emulator, and `home/h82/dev/android.nix` reads `latest.ndk` and `latest.cmdline-tools`. androidenv's `coerceIntVersion` takes the major of `37.0`, so its own use of `latest.platforms` stays valid.

### Assumptions

- AGP 9.1.1 or newer resolves `compileSdk = 37` to `platforms/android-37.0`; Google's AGP compatibility table names 9.1.1 as the minimum for API 37.0. An older AGP or Flutter Gradle plugin asks for `android-37`, which upstream does not publish and no pin can provide (Flutter issue #192478). This is not exercised by a check here.
- The pinned emulator `37.2.12` (or newer after the refresh) satisfies the `37.0` image's minimum of `36.5.11`; the release script refuses the pin otherwise.
- nixpkgs' `repo.json` already carries `platforms` `37.0`, `build-tools` `37.0.0`, and the `37.0` image with the same archives as upstream, so `android-sdk-repo-parity` compares them rather than skipping them.

### Risks

- The `37.0` system image adds about 4 GB unpacked to every x86_64 host closure (the API 36 image measures 4.3 GB in the store), plus its 2.2 GB zip in any CI store that builds it. The `check-shards` and `hosts` jobs build the SDK on ubuntu-24.04 runners, so they may run out of disk. This is the cost the issue accepts by asking for the image; the Verification Contract checks those jobs for disk exhaustion.
- The tracked-package refresh in KTD3 may bump cmdline-tools, emulator, or platform-tools in the same commit. The existing check asserts each against the pin, so a bump is verified the same way the scheduled update is.

## Implementation Units

### U1. Regenerate the pin with both API levels

- **Goal:** `packages/android-sdk-repo.json` declares platforms `36` and `37.0`, build-tools `36.0.0` and `37.0.0`, and the `google_apis` x86_64 image for both.
- **Requirements:** R1, R2, R3, R4; KTD1, KTD2, KTD3.
- **Dependencies:** none.
- **Files:** `packages/android-sdk-repo.json`.
- **Approach:**
  1. Run `android-sdk-release` against the pin with both repeated flags, per KTD3.
  2. Confirm the new entries carry `android-sdk-license` and that `latest` names `37.0` and `37.0.0`.
  3. Run it again with no flags and confirm the file is reported up to date.
- **Patterns to follow:** the declared-version flow in `scripts/android-sdk-release` (`select_versions`, `select_images`).
- **Test scenarios:**
  - A flagless second run leaves the pin byte-identical (covers R4).
  - `android-sdk-repo-parity` compares the `37.0` platform, `37.0.0` build-tools, and `37.0` image rather than skipping them.
- **Verification:** the pin lists both levels; the parity and release-script checks pass.

### U2. Assert both API levels in the android-sdk check

- **Goal:** `tests/android-sdk.nix` fails when either API level's platform, build-tools, or system image is missing from a host's materialized SDK, independently of what the pin declares.
- **Requirements:** R1, R2, R3, R5; KTD4.
- **Dependencies:** U1.
- **Files:** `tests/android-sdk.nix`.
- **Approach:**
  1. Add a fixed list of required API levels, each a platform key and an exact build-tools version, and document it in the header comment's verification list.
  2. For each level, emit builder assertions on the materialized directories under `$sdk`, and run `aapt2` from that build-tools directory.
  3. Give the fixed-list failures their own message wording, distinct from the pin-driven assertions, and report every missing path rather than stopping at the first.
  4. Keep the existing pin-driven assertions unchanged.
- **Patterns to follow:** the `concatMapStrings` assertion blocks and the `fail` helper already in `tests/android-sdk.nix`; the mutation-testing learnings under `.compound-engineering/artifacts/solutions/best-practices/` named in `AGENTS.md`.
- **Execution note:** prove each assertion by mutation in a scratch copy, following the copied-worktree learning, rather than trusting it from a green run.
- **Test scenarios:**
  - With the pin from U1, the check passes on every configuration.
  - Removing `37.0` from `platformVersions` in `packages/android-sdk.nix` (pin unchanged) fails the check. This is a regression scenario for R5; the existing pin-driven assertions already catch it, so it does not prove the fixed list.
  - Each of these pin mutations, where only the fixed list can fail, fails the check with the fixed-list wording and names every path it removed:
    - remove platform `36` and its `36` image, keeping build-tools `36.0.0`
    - remove only build-tools `36.0.0`
    - remove platform `37.0` and its `37.0` image, keeping build-tools `37.0.0`
    - remove only build-tools `37.0.0`
- **Verification:** each fixed-list mutation fails the build with the fixed-list message naming each removed path; the unmutated tree passes.

### U3. Cover a dotted platform key in the release-script tests

- **Goal:** `tests/test_android_sdk_release.py` proves the script pins a minor-level platform key such as `37.0` beside `36`, with its image and with `latest` pointing at it.
- **Requirements:** R4; KTD1.
- **Dependencies:** none.
- **Files:** `tests/test_android_sdk_release.py`.
- **Approach:** add a `37.0` platform and image to the fixture XML and one test that declares both platforms, then re-runs without flags.
- **Patterns to follow:** `test_image_follows_a_second_declared_platform` and `test_later_run_keeps_declared_versions_from_the_pin`.
- **Test scenarios:**
  - `--platforms 36 --platforms 37.0` pins both platforms and both images, and `latest.platforms` is `37.0`.
  - A later flagless run keeps both platforms declared.
- **Verification:** the `android-sdk-release` check passes, and fails when the script is mutated to keep only the newest declared platform.

### U4. Update the verification guide for API 37

- **Goal:** `docs/verification.md` tells the operator how to build against and emulate API 37 from the pin.
- **Requirements:** R1, R3.
- **Dependencies:** U1.
- **Files:** `docs/verification.md`.
- **Approach:** note that API 37 is the `android-37.0` package, that `compileSdk 37` resolves to it on AGP 9.1.1 or newer, and that a `Failed to find target with hash string 'android-37'` error means the project's AGP is too old (passing `--platforms 37` is refused). Give the AVD example for `system-images;android-37.0;google_apis;x86_64` beside the existing API 36 one.
- **Test expectation:** none -- documentation only.
- **Verification:** the guide names package paths that exist in the pin.

## Verification Contract

| Gate | Command | Proves |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | Nix layout |
| Flake checks | `nix flake check` | `android-sdk-release`, `android-sdk-repo-parity`, and the other declared checks evaluate and build |
| SDK check | `nix build --no-link .#checks.x86_64-linux.android-sdk` | R1, R2, R3, R5 on every configuration |
| Host builds | the loops in `AGENTS.md` over `nixosConfigurations`, `homeConfigurations`, `systemConfigs` | R6 |
| Mutation | scratch-copy mutations listed in U2 and U3 | the new assertions are not decorative |
| CI disk | the PR's `check-shards` and `hosts` job logs | no job failed for lack of disk space after the second image |

## Definition of Done

- U1 to U4 are complete and their verification holds.
- Every gate in the Verification Contract passes; any gate that cannot run locally (aarch64 outputs) is reported as not run.
- Mutation results from U2 and U3 are recorded in the PR body.
- No abandoned experiment or mutation remains in the diff.

## Sources

- Issue #153, `https://github.com/hyperlapse122/nix-config/issues/153`.
- Upstream `https://dl.google.com/android/repository/repository2-3.xml` and `sys-img/google_apis/sys-img2-3.xml` (read 2026-10-05): `platforms;android-37.0` r2, `build-tools;37.0.0`, image `37.0` r6, all `android-sdk-license` on `channel-0`.
- Flutter issue #192478 (`Failed to find target with hash string 'android-37'`) and the AGP 9.2 release notes: API 37 ships only as `android-37.0`.
- `scripts/android-sdk-release`, `packages/android-sdk.nix`, `home/h82/dev/android.nix`, `tests/android-sdk.nix`, `tests/android-sdk-repo-parity.py`.
