---
title: ThinkPad Thunderbolt authorization for Apple Studio Display - Plan
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# ThinkPad Thunderbolt authorization for Apple Studio Display - Plan

## Goal Capsule

- **Objective:** On `ThinkPad-X1-Carbon-Gen-11`, a connected Apple Studio Display's built-in camera, speakers, and microphones are usable as soon as it is plugged in, not only its video output.
- **Means:** Enable bolt on the ThinkPad through a new hardware module, which also brings in Plasma's Thunderbolt settings module, and guard it with a flake check on the built system (KTD1, KTD2).
- **Authority:** This plan's R-IDs, then Key Decisions, then KTDs.
- **Execution profile:** Lightweight. Three units.
- **Stop conditions:** Stop if the built ThinkPad system does not carry the bolt unit, its udev rule, or the Plasma Thunderbolt module, or if any host build fails.
- **Finish and ship:** `ce-work` implements. Hardware authorization and device checks follow `docs/verification.md` after a user-run rebuild.

---

## Product Contract

### Summary

The ThinkPad configuration runs bolt, the Thunderbolt device manager, and ships Plasma's Thunderbolt settings module. Because this ThinkPad's Thunderbolt domain has IOMMU DMA protection, bolt enrolls and authorizes each new Thunderbolt device on first connection with no prompt, the Studio Display included, and re-authorizes it on every later connection. The Plasma module lists stored devices and lets the user forget one. A flake check reads the built system for both ThinkPad configurations.

### Problem Frame

The Studio Display carries a camera, speakers, microphones, and a brightness HID interface behind a Thunderbolt-tunneled USB hub. On the ThinkPad, the Thunderbolt domain runs at security level `user`, so the kernel keeps every new Thunderbolt device unauthorized until something in userspace approves it. Nothing in this flake does that today. With the display attached, `/sys/bus/thunderbolt/devices/1-1` reports `Apple Inc.` / `Studio Display` with `authorized=0`, `bolt` is inactive, and no Studio Display hidraw node exists. Video still works because DisplayPort tunneling does not wait for authorization: `DP-3` offers 5120x2880.

### Requirements

**Authorization**

- R1. Both ThinkPad configurations (`ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`) run bolt, started automatically when a Thunderbolt device appears.
- R2. Both ThinkPad configurations ship Plasma's Thunderbolt settings module, so the user can review stored devices and forget one from System Settings without a terminal.
- R3. A connected Thunderbolt device is authorized on first connection and again on reconnect and after reboot, with no user interaction.

**Guard**

- R4. A flake check registered in `flake.nix` fails when either ThinkPad configuration's built system loses R1 or R2.

### Key Decisions

- **bolt, accepting automatic authorization of every Thunderbolt device.** (session-settled: user-directed — chosen over a udev rule that authorizes only vendor `0x1` / device `0x801f`: bolt handles every Thunderbolt device the same way with a Plasma management screen; the user accepted, with the behavior shown, that under IOMMU protection bolt authorizes any new Thunderbolt device without a prompt, even at a locked screen, and that IOMMU DMA protection is the remaining mitigation.) Governs R1, R2, R3.
- **ThinkPad only.** The request named the ThinkPad host. Governs R1, R2, R4.

### Scope Boundaries

- Brightness control is out of scope: neither `asdbctl` nor the out-of-tree `hid-apple-studio-display` backlight driver.
- `MS-7D91` is out of scope. The check makes no assertion about it either way.
- bolt's enrollment store (`/var/lib/boltd`) is runtime state and is not managed declaratively.
- Camera and audio need no configuration of their own in this plan. Once the hub is authorized they bind to the standard UVC and USB audio drivers under PipeWire, which hardware verification confirms (see Assumptions).

### Sources

- nixpkgs (locked rev `4975466d324710c576dc11ad614684e6bd8cad8e`) `nixos/modules/services/hardware/bolt.nix`: `services.hardware.bolt.enable` defaults to `false` and adds the package to `environment.systemPackages`, `services.udev.packages`, and `systemd.packages`.
- Same rev, `nixos/modules/services/desktop-managers/plasma6.nix`: `plasma-thunderbolt` is added to the system packages only when `services.hardware.bolt.enable` is true. Plasma 6 does not enable bolt itself; only the GNOME and Cinnamon modules default it on.
- Same rev, `nixos/modules/services/system/dbus.nix`: `services.dbus.packages` includes `config.system.path`, so bolt's `share/dbus-1/system.d/org.freedesktop.bolt.conf` reaches the system bus once bolt is in the system path.
- `bolt-0.9.8` ships `lib/systemd/system/bolt.service` (`Type=dbus`, `StateDirectory=boltd`), `lib/udev/rules.d/90-bolt.rules` (`SUBSYSTEM=="thunderbolt", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bolt.service"`), `bin/boltctl`, and a polkit rule granting enroll/authorize to active local `wheel` members.
- `plasma-thunderbolt-6.7.5` ships `lib/qt-6/plugins/plasma/kcms/systemsettings/kcm_bolt.so`, `share/applications/kcm_bolt.desktop`, and the `kded_bolt` notifier.
- Live ThinkPad readings: `/sys/bus/thunderbolt/devices/domain1/security` is `user`, `iommu_dma_protection` is `1`, and `1-1` is the unauthorized Studio Display.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **A new `modules/nixos/hardware/thunderbolt.nix` sets `services.hardware.bolt.enable = true`, imported only by `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.** This keeps the host's `hardware.nix` limited to generated hardware facts and matches the per-concern modules under `hardware/`. The bootstrap configuration shares the host imports, and bolt needs no secrets, so both ThinkPad configurations get it. The module's comment names the Plasma coupling: without bolt, `plasma6.nix` also drops `plasma-thunderbolt`. Instantiates the bolt Key Decision (R1, R2, R3).
- KTD2. **The check reads the built system, not `services.hardware.bolt.enable`.** Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md` and `nix-check-assertion-on-unconditional-option-folds-to-a-constant.md`, it asserts four artifacts for each ThinkPad configuration:
  1. `bolt.service` in the materialized `etc."systemd/system"` tree.
  2. The `90-bolt.rules` start line, verbatim, in the materialized `etc."udev/rules.d"` directory.
  3. `bin/boltctl` in `system.path`.
  4. `kcm_bolt.so` under `lib/qt-6/plugins/plasma/kcms/systemsettings/` and `share/applications/kcm_bolt.desktop` in `system.path`.

  Each attribute access is guarded with `or null`, so a missing artifact fails inside the builder rather than during evaluation. That follows `unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`. Every failure is collected before exiting, as in `tests/udev-device-access.nix`.

### Assumptions

- Once authorized, the Studio Display's camera enumerates as a UVC device and its speakers and microphones as a USB audio device under PipeWire, with no extra firmware or quirk. No repository check can reach this; hardware verification settles it.
- bolt's polkit rule loads from the system path's `share/polkit-1/rules.d` (NixOS links `/share/polkit-1`), so forgetting a device from Plasma needs no password for `wheel` members. If it does not load, polkit's default `auth_admin_keep` asks for the password once.
- With `iommu_dma_protection=1`, bolt enrolls each new device with the `iommu` policy and authorizes it without user interaction (`boltd(8)`, bolt-0.9.8). That is what makes R3 hold. If a firmware or kernel change turns IOMMU protection off, devices enrolled with the `iommu` policy stop being authorized automatically.

### Risks

- A future nixpkgs change that makes Plasma enable bolt by default would make the module redundant but not wrong. The check still passes.
- Every Thunderbolt device plugged into the ThinkPad is authorized, including at a locked screen, so a malicious USB HID or PCIe function behind Thunderbolt is no longer held back by the `user` security level. IOMMU DMA protection limits DMA only. The user accepted this in the Key Decision.
- When the firmware supports BootACL, bolt adds each enrolled device to the controller's pre-boot list, and the firmware then authorizes it before the OS starts without verification. Forgetting the device in Plasma or with `boltctl forget` removes it. Hardware verification records whether BootACL is active.

---

## Implementation Units

### U1. Add the Thunderbolt hardware module

- **Goal:** Satisfy R1, R2, and R3 on both ThinkPad configurations.
- **Requirements:** R1, R2, R3. KTD1.
- **Dependencies:** none.
- **Files:** `modules/nixos/hardware/thunderbolt.nix`, `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
- **Approach:**
  1. Create the module with `services.hardware.bolt.enable = true`.
  2. Add a short comment: the ThinkPad's Thunderbolt domain runs at security level `user`, so devices such as the Studio Display stay unauthorized until bolt authorizes them. With IOMMU DMA protection active, bolt does that for every new device without a prompt, which is the accepted posture. Enabling bolt is also what makes Plasma ship its Thunderbolt settings module.
  3. Import it from `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` beside the other `hardware/` modules.
- **Patterns to follow:** `modules/nixos/hardware/bluetooth-audio.nix` for module shape and comment density.
- **Test expectation:** covered by U2's check.
- **Verification:** Both ThinkPad toplevels build, and `nix fmt -- --ci` passes.

### U2. Add the Thunderbolt flake check

- **Goal:** Fail the build when either ThinkPad configuration stops shipping bolt or the Plasma Thunderbolt module (R4).
- **Requirements:** R4. KTD2.
- **Dependencies:** U1.
- **Files:** `tests/thunderbolt.nix`, `flake.nix`.
- **Approach:**
  1. Take `{ pkgs, self }` and open with the `Check interface:` header comment block used by `tests/udev-device-access.nix`, stating what the check reads and what it cannot see (whether a real device gets authorized).
  2. For each ThinkPad configuration, resolve the three roots (`environment.etc."systemd/system".source`, `environment.etc."udev/rules.d".source`, `system.path`) with `or null`, and report an absent root inside the builder.
  3. Assert the four artifacts in KTD2, collecting every failure and exiting non-zero at the end.
  4. Register it as `thunderbolt` beside `wireplumber-bluetooth` in `flake.nix`.
- **Patterns to follow:** `tests/udev-device-access.nix` for the failure-collecting helper and the materialized udev directory. `tests/yubikey-fido.nix` for asserting files in `system.path`.
- **Test scenarios:**
  - Happy path: both ThinkPad configurations carry all four artifacts, and the check builds.
  - Error path: removing the import from `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` fails the check for both configurations, naming every missing artifact.
  - Error path: setting `services.hardware.bolt.enable = lib.mkForce false` in the module fails the check with the check's own messages, not an evaluation error.
  - Error path: keeping bolt on while a temporary `nixpkgs.overlays` entry replaces `kdePackages.plasma-thunderbolt` with an empty derivation (via `kdePackages.overrideScope`) fails only the Plasma module assertions. `environment.plasma6.excludePackages` cannot express this mutation, because `plasma6.nix` appends `plasma-thunderbolt` after its exclusion filter.
  - Error path: keeping bolt on while setting `services.udev.packages` to omit bolt (for example with `lib.mkForce` on a list without it) fails only the udev rule assertion.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.thunderbolt` passes on the real configuration. Each mutation above fails inside the builder with the check's message (read with `nix log`), and every mutation is reverted afterward.

### U3. Document the check and the hardware authorization

- **Goal:** Record what the check covers and what only hardware can confirm.
- **Requirements:** R1, R2, R3, R4.
- **Dependencies:** U2.
- **Files:** `docs/verification.md`.
- **Approach:**
  1. Under "Repository checks", add a sentence describing `thunderbolt`: what it reads from the built system and that it cannot see whether a real device gets authorized.
  2. Under "Hardware checks after installation", add a `ThinkPad-X1-Carbon-Gen-11` checkbox. Its steps: plug in the Studio Display and confirm, with no prompt, that `boltctl list` shows it authorized and stored with policy `iommu` and that it appears in System Settings > Thunderbolt. Record whether `boltctl domains` reports BootACL support. Then confirm the camera appears to a video application, and that the Studio Display speakers and microphones appear as a PipeWire sink and source. Finally, unplug and replug, then reboot, and confirm it re-authorizes with no interaction (R3). Also record in the Studio Display entry that bolt now authorizes every Thunderbolt device automatically, so a reader of the checklist knows the posture.
- **Test expectation:** none -- documentation only.
- **Verification:** The new entries use the existing checklist style and name the host.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.thunderbolt` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, MS-7D91-bootstrap |

Hardware authorization and device checks (U3's checkbox) happen after a user-run rebuild. Report them separately from build evidence, per `docs/verification.md`. Do not run `nixos-rebuild switch` as validation.

## Definition of Done

- U1, U2, and U3 landed. The check passes on the real configuration and fails under each U2 error-path mutation.
- `nix fmt -- --ci`, `nix flake check`, and all four host builds pass.
- No mutation or experiment code remains in the diff.
