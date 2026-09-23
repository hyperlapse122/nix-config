---
title: ThinkPad Lid-Switch Suspend-Then-Hibernate - Plan
type: feat
date: 2026-09-23
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# ThinkPad Lid-Switch Suspend-Then-Hibernate - Plan

## Goal Capsule

- **Objective:** Closing the ThinkPad-X1-Carbon-Gen-11's lid while running on battery stops the machine from draining its battery unattended, without changing lid behavior while it is plugged in or docked.
- **Means:** Configure KDE Powerdevil's per-profile lid action — the mechanism actually in effect during a running Plasma session (KTD3) — plus systemd-logind's lid-switch settings as a pre-login/no-session fallback (KTD1), both scoped to the ThinkPad host only (KTD4).
- **Authority hierarchy:** GitHub issue [#57](https://github.com/hyperlapse122/nix-config/issues/57) states the request and acceptance criteria; this plan resolves the exact mechanism from repository and upstream-source evidence, since the issue's proposed snippet alone does not reach the running desktop (see Key Decisions).
- **Stop conditions:** Regression checks (U3) must fail when any profile's lid action is wrong, when the Powerdevil config leaks to `MS-7D91`, or when the logind fallback settings regress.
- **Execution profile:** Standard, single-repo, no external contracts. Config-only change across two subsystems (systemd-logind, KDE Powerdevil) plus build-time regression checks.
- **Finishes and ships:** `ce-work` implements and verifies; the plan's own PR carries the change.

---

## Product Contract

### Summary

Configure lid-switch behavior on `ThinkPad-X1-Carbon-Gen-11` so closing the lid on battery power triggers suspend-then-hibernate, while closing the lid on external AC power or with an external monitor connected ("docked") does nothing. `MS-7D91` is untouched. Because this host runs the default Plasma desktop, the change must reach KDE Powerdevil — the component that actually owns lid-switch handling whenever a session is active — not only `systemd-logind`.

### Problem Frame

Nothing in this repository currently declares `services.logind` or Powerdevil's `SuspendAndShutdown` settings (confirmed by a repository-wide search), so both fall back to their upstream defaults. Powerdevil's own default (`ProfileDefaults::defaultLidAction`) already suspends the machine to RAM on lid close on every power profile — the ThinkPad does not stay fully awake with the lid down. A plain RAM suspend still draws power (self-refresh, wake sources), so a ThinkPad left closed on battery for an extended period (a trip, a long weekend) can still exhaust its battery from suspend alone. Converting the battery-profile lid action to suspend-then-hibernate closes that gap by powering the machine off entirely after a bounded delay.

### Requirements

- R1. On battery power, closing the lid on `ThinkPad-X1-Carbon-Gen-11` triggers suspend-then-hibernate.
- R2. On external AC power, closing the lid on `ThinkPad-X1-Carbon-Gen-11` is ignored (no sleep action).
- R3. While an external monitor is connected ("docked"), closing the lid on `ThinkPad-X1-Carbon-Gen-11` is ignored, regardless of power source.
- R4. `MS-7D91` renders none of the ThinkPad-only lid-switch configuration — neither the logind settings nor the Powerdevil activation entry — and is unaffected by construction, not merely unbuilt.
- R5. `nix fmt -- --ci`, `nix flake check`, and both ThinkPad host builds (`ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap`) succeed.

### Key Decisions

- **The mechanism must be KDE Powerdevil, not only `services.logind`.** Governs R1, R2, R3. `modules/nixos/desktop.nix` enables `services.desktopManager.plasma6.enable` for both hosts, and upstream KDE Powerdevil (`daemon/powerdevilpolicyagent.cpp`, `setupSystemdInhibition()`) unconditionally takes a `block`-mode systemd-logind inhibitor over `handle-lid-switch` (and the power/suspend/hibernate keys) the instant its D-Bus service registers. While that inhibitor holds — i.e., for the entire duration of any running Plasma session — logind never executes `HandleLidSwitch`/`HandleLidSwitchExternalPower`/`HandleLidSwitchDocked` on a raw lid-close event; Powerdevil decides the action itself from its own per-profile `LidAction`/`SleepMode` settings and calls `logind.SuspendThenHibernate()` directly when configured to. The GitHub issue's proposed `services.logind` snippet, taken alone, would pass every build-time check in this plan's original form while having no effect on the actual running desktop. (Sources & Research)
- **Write to `services.logind.settings.Login`, not the issue's proposed option names, for the fallback layer.** Governs R1, R2, R3 (fallback path only). The issue's proposed snippet (`services.logind.lidSwitch`, `lidSwitchExternalPower`, `lidSwitchDocked`) names options nixpkgs (pinned rev `20b1ddd1`) renames to `services.logind.settings.Login.Handle*` via `mkRenamedOptionModule`. The old names still evaluate today with a deprecation warning; writing the surviving option directly avoids shipping code that is deprecated the day it lands. (Sources & Research)

### Scope Boundaries

- **In scope:** Powerdevil's per-profile lid action on `ThinkPad-X1-Carbon-Gen-11` (primary mechanism), `services.logind`'s lid-switch settings on the same host (fallback), and build-time regression checks for both.
- **Outside this product's identity:** `MS-7D91` — the issue explicitly scopes this to the ThinkPad.
- **Deferred to Follow-Up Work:**
  - `systemd.sleep` tuning (e.g. `HibernateDelaySec`) — the issue's References section names a legacy `sleep.conf.d` file for context, but neither Proposed Changes nor Acceptance Criteria ask for it.
  - Hibernation resume-offset wiring (`boot.resumeDevice` and, for a btrfs swapfile, `resume_offset=`) — not requested, and not computable from static configuration (see Risks).

### Sources & Research

- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` — host-local overrides (e.g. `config.my.keyd.copilotKey`) already live directly in this file; the logind fallback settings follow that pattern.
- `modules/nixos/desktop.nix:3` — `services.desktopManager.plasma6.enable = true;`, imported by both hosts, establishing that Powerdevil is always present.
- `home/h82/kde/autostart.nix` — existing precedent for host-scoping a shared home-manager module with `osConfig`: `lib.mkIf (!osConfig.my.bootstrap) { ... }` wrapping the whole file's config; this plan's Powerdevil unit mirrors that shape with `osConfig.networking.hostName == "ThinkPad-X1-Carbon-Gen-11"`.
- `home/h82/kde/session.nix` — existing precedent for writing `powerdevilrc` via `${pkgs.kdePackages.kconfig}/bin/kwriteconfig6` inside a `home.activation` entry (`--group AC --group Display --key DimDisplayWhenIdle --type bool false`, etc.); this plan's Powerdevil unit follows the same tool and activation shape.
- nixpkgs `nixos/modules/system/boot/systemd/logind.nix` (pinned rev `20b1ddd1aa5ace70c9468305030aa4f9ef79671b`): `services.logind.settings.Login` is a freeform submodule rendered verbatim by `environment.etc."systemd/logind.conf".text = utils.systemdUtils.lib.settingsToSections config.services.logind.settings`, unconditional whenever `services.logind.enable` (default `true`, untouched here). The `lidSwitch`/`lidSwitchExternalPower`/`lidSwitchDocked` convenience options are aliased to `settings.Login.Handle*` via `mkRenamedOptionModule`.
- KDE Powerdevil upstream source (`invent.kde.org/plasma/powerdevil`, `master` branch read during planning):
  - `daemon/powerdevilpolicyagent.cpp`, `setupSystemdInhibition()` — the unconditional `block`-mode inhibitor over `handle-power-key:handle-suspend-key:handle-hibernate-key:handle-lid-switch`.
  - `PowerDevilProfileSettings.kcfg` — the `SuspendAndShutdown` group (nested under each profile: `AC`, `Battery`, `LowBattery`) carrying `LidAction` (UInt), `SleepMode` (UInt, default `SuspendToRam`), and `InhibitLidActionWhenExternalMonitorPresent` (Bool, default `true`).
  - `daemon/powerdevilenums.h` — `PowerButtonAction` (`NoAction=0`, `Sleep=1`, `Hibernate=2`, ...) and `SleepMode` (`SuspendToRam=1`, `HybridSuspend=2`, `SuspendThenHibernate=3`).
  - `daemon/actions/bundled/handlebuttonevents.cpp`, `onLidClosedChanged()`/`triggersLidAction()` — a closed lid is suppressed (no action) whenever an external monitor is present and `InhibitLidActionWhenExternalMonitorPresent` is true (the default), independent of AC/Battery profile.
  - `daemon/actions/bundled/suspendsession.cpp`, `triggerImpl()` — `LidAction=Sleep` with the profile's `SleepMode=SuspendThenHibernate` calls `suspendController()->suspendThenHibernate()`, which (`daemon/controllers/suspendcontroller.cpp`) calls `org.freedesktop.login1.Manager`'s `SuspendThenHibernate` directly — the same underlying systemd action R1 asks for, reached through Powerdevil instead of a raw lid-switch event.
  - `daemon/powerdevilsettingsdefaults.cpp`, `defaultLidAction()` — confirms the upstream default (`Sleep`) is the same across all three profiles, cited in Problem Frame.
- nixpkgs kernel config `pkgs/os-specific/linux/kernel/common-config.nix:861` (pinned rev `20b1ddd1`) — `SECURITY_LOCKDOWN_LSM = no;`, set unconditionally. A reviewer concern that this host's Secure Boot (`boot.lanzaboote.enable`) would trigger kernel lockdown and block hibernation was checked against this line and does not apply: nixpkgs' kernel does not compile in the Lockdown LSM at all, so no Secure Boot state can activate it.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep the `services.logind.settings.Login` declaration as a fallback layer, added directly to `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.** It only governs a raw lid-switch event when no process holds a `block`-mode inhibitor on `handle-lid-switch` — i.e., before login, or if Powerdevil is not running — but it is cheap, correct, and matches the issue's literal proposed change, so it stays as defense-in-depth. Governs R1, R2, R3 (fallback path).
- KTD2. **U3's regression check asserts materialized output on both surfaces, not raw option values.** For logind, it reads `environment.etc."systemd/logind.conf".text` (the file `services.logind`'s module actually renders), not the option value directly — the gap the repo's `nix-check-reads-option-value-not-materialized-output` learning describes. For Powerdevil, it reads the rendered `home.activation.kdePowerLid.data` shell script (the same pattern `tests/plasma-taskbar.nix` already uses for `home.activation.kdePlasmaApplets`), not the Nix-level option that produced it. Asserting `environment.etc."systemd/logind.conf".enable` would be decorative here: nothing in this diff can make `services.logind.enable` false (per the repo's `nix-check-assertion-on-unconditional-option-folds-to-a-constant` learning), so that flag is deliberately left unasserted.
- KTD3. **Powerdevil's per-profile `LidAction`/`SleepMode`/`InhibitLidActionWhenExternalMonitorPresent` are the primary mechanism, configured via a new `home/h82/kde/power-lid.nix`.** Set `LidAction=1 (Sleep)` and `SleepMode=3 (SuspendThenHibernate)` on the `Battery` and `LowBattery` profiles (R1), `LidAction=0 (NoAction)` on the `AC` profile (R2), and `InhibitLidActionWhenExternalMonitorPresent=true` (explicit, matching upstream default) on all three profiles (R3). This is the config KDE actually consults while a session is running (Key Decisions), and `InhibitLidActionWhenExternalMonitorPresent` implements R3's "docked" requirement directly and correctly — unlike the logind-layer equivalent (see Risks).
- KTD4. **Scope the new Powerdevil unit to `ThinkPad-X1-Carbon-Gen-11` with `osConfig.networking.hostName`, mirroring `home/h82/kde/autostart.nix`'s existing `lib.mkIf (!osConfig.my.bootstrap) { ... }` shape.** `home-manager.users.h82` is imported once, unconditionally, for both hosts (`flake.nix`), so a new file under `home/h82/kde/` reaches `MS-7D91` unless it is wrapped the same way `autostart.nix` already wraps a bootstrap-conditional file. Governs R4.

### Risks & Dependencies

- **Hibernation resume is not wired.** Suspend-then-hibernate still achieves R1's goal (the machine truly powers off after the hibernate delay) because writing a hibernation image to swap needs no resume configuration — only *reading it back at boot* does. Without `boot.resumeDevice`/`resume_offset=` for the btrfs swapfile, the next boot will not detect the image and will boot fresh instead of restoring the previous session. This is a session-continuity cost, not a battery-drain risk, and it is out of scope (see Scope Boundaries) because the resume offset can only be computed post-install (`btrfs inspect-internal map-swapfile`). Recorded as a hardware-verification item in U3.
- **The logind-layer "docked" check is broader than a real dock, but this no longer matters for the active mechanism.** systemd's own `manager_is_docked_or_external_displays()` (`src/login/logind-core.c`) treats *any* connected, enabled external display as "docked" for lid-switch purposes — not only a literal docking station — and that "docked" branch takes precedence over both the battery and AC-power branches. Under the fallback (logind-only, no Plasma session) path, closing the lid with an external monitor attached is ignored even on battery with no dock present. This is moot for the primary mechanism: Powerdevil's own `InhibitLidActionWhenExternalMonitorPresent` (KTD3) implements the same "external display suppresses lid action" semantics directly, correctly, and is what actually runs during normal use. The residual quirk only applies to the no-session fallback layer, which is a narrower and less consequential window.
- **Swap size relative to installed RAM is not verified from static configuration.** systemd requires the swap to hold a full hibernation image; the ThinkPad's 64G btrfs swapfile is generous, but whether it is sufficient for this specific machine's installed RAM is a hardware fact, not a Nix-evaluable one. Recorded as a hardware-verification item in U3.

---

## Implementation Units

### U1. Declare ThinkPad lid-switch behavior via logind (fallback layer)

**Goal:** Configure `suspend-then-hibernate` on lid close while on battery, and ignore lid close on external AC power or while docked, as a fallback for when no Plasma session holds the systemd-logind lid-switch inhibitor.

**Requirements:** R1, R2, R3 (fallback path), R4 (satisfied by construction — no shared module or `MS-7D91` file is touched).

**Dependencies:** none

**Files:**
- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` (modify)

**Approach:**
- Add `config.services.logind.settings.Login = { HandleLidSwitch = "suspend-then-hibernate"; HandleLidSwitchExternalPower = "ignore"; HandleLidSwitchDocked = "ignore"; };` alongside the file's existing `config.my.*` assignments (KTD1).
- Use `services.logind.settings.Login.Handle*`, not the `lidSwitch`/`lidSwitchExternalPower`/`lidSwitchDocked` convenience names the issue's snippet shows (Key Decision, Sources & Research).
- Do not modify `hosts/MS-7D91/default.nix` or any shared `modules/nixos/*.nix` file.

**Patterns to follow:** the file's existing `config.my.keyd.copilotKey = false;`-style host-local overrides.

**Test scenarios:** `Test expectation: none -- pure declarative configuration with no branch to unit test in isolation; covered end-to-end by U3's regression check.`

**Verification:** `nix build --no-link .#checks.x86_64-linux.logind-lid-switch` (from U3) passes.

### U2. Configure Powerdevil per-profile lid action (primary mechanism)

**Goal:** Make the lid actually behave as R1-R3 describe during normal Plasma use, where Powerdevil — not logind — decides the lid action.

**Requirements:** R1, R2, R3, R4 (satisfied by host-scoping, not by omission).

**Dependencies:** none

**Files:**
- `home/h82/kde/power-lid.nix` (new)
- `home/h82/kde/default.nix` (modify — register the import)

**Approach:**
1. Create `home/h82/kde/power-lid.nix` with signature `{ pkgs, lib, osConfig, ... }:`, matching `home/h82/kde/autostart.nix`.
2. Wrap the whole returned attrset in `lib.mkIf (osConfig.networking.hostName == "ThinkPad-X1-Carbon-Gen-11")` (KTD4).
3. Inside, declare one `home.activation.kdePowerLid = lib.hm.dag.entryAfter [ "writeBoundary" ] '' ... '';` entry that, when `${kwrite}` (`${pkgs.kdePackages.kconfig}/bin/kwriteconfig6`, the constant `home/h82/kde/session.nix` already defines) is executable, writes to `powerdevilrc`:
   - `Battery` and `LowBattery` profiles: `SuspendAndShutdown` group, `LidAction` = `1`, `SleepMode` = `3`.
   - `AC` profile: `SuspendAndShutdown` group, `LidAction` = `0`.
   - `AC`, `Battery`, and `LowBattery` profiles: `SuspendAndShutdown` group, `InhibitLidActionWhenExternalMonitorPresent`, `--type bool true`.
4. Add `./power-lid.nix` to the `imports` list in `home/h82/kde/default.nix`.

**Patterns to follow:** `home/h82/kde/autostart.nix` (host-scoping shape via `osConfig`); `home/h82/kde/session.nix` (the `kwriteconfig6` constant and `home.activation` shape for `powerdevilrc`).

**Test scenarios:** `Test expectation: none -- pure declarative configuration with no branch to unit test in isolation; covered end-to-end by U3's regression check.`

**Verification:** `nix build --no-link .#checks.x86_64-linux.logind-lid-switch` (from U3, extended to cover this unit) passes; the hardware checklist item in U3 confirms the effect on real hardware.

### U3. Add a regression check and record verification

**Goal:** Guard both the logind fallback and the Powerdevil mechanism at build time — a future edit that drops or weakens either, or lets the Powerdevil config leak to `MS-7D91`, fails `nix flake check` — and record the hardware-verification steps a build-time check cannot cover.

**Requirements:** R4, R5.

**Dependencies:** U1, U2

**Files:**
- `tests/logind-lid-switch.nix` (new)
- `flake.nix` (modify — register the check)
- `docs/verification.md` (modify — describe the check and add hardware checklist items)

**Approach:**
1. Follow the `tests/plasma-taskbar.nix` pattern: for each of `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, and `MS-7D91`, resolve the host from `self.nixosConfigurations`.
2. Logind surface: read `host.config.environment.etc."systemd/logind.conf".text`, materialize it with `pkgs.writeText`, and assert with explicit `if ... ; then echo ... >&2; exit 1; fi` branches (never `! grep`, per the decorative-assertion learning) that both ThinkPad configurations render `HandleLidSwitch=suspend-then-hibernate`, `HandleLidSwitchExternalPower=ignore`, and `HandleLidSwitchDocked=ignore`, and that `MS-7D91` renders none of the three keys.
3. Powerdevil surface: read `host.config.home-manager.users.h82.home.activation.kdePowerLid.data or null`, matching `tests/plasma-taskbar.nix`'s `.data or null` pattern for the absent case. Materialize the non-null value with `pkgs.writeText` and assert both ThinkPad configurations set `LidAction` `1`/`1`/`0` for `Battery`/`LowBattery`/`AC` respectively, `SleepMode` `3` for `Battery`/`LowBattery`, and `InhibitLidActionWhenExternalMonitorPresent` `true` for all three profiles; assert `MS-7D91`'s value is `null` (the activation entry must not exist there at all, not merely be empty).
4. Register `logind-lid-switch = import ./tests/logind-lid-switch.nix { inherit pkgs self; };` in `flake.nix`'s `checks.${system}` set.
5. Extend `docs/verification.md`'s "Repository checks" paragraph with one sentence naming what `logind-lid-switch` asserts (mirroring the prose style already used for `plasma-taskbar` and `nix-cleanup`), covering both the logind and Powerdevil surfaces.
6. Add checklist items under "Hardware checks after installation": confirm closing the lid on battery suspends the machine and, after the hibernate delay, powers it off; confirm closing the lid on AC power and with an external monitor connected does neither; confirm the 64G swapfile is large enough for this machine's installed RAM to hold a hibernation image; and record that the next boot starts fresh rather than resuming the previous session, since this repository configures no hibernation resume offset for the btrfs swapfile (Risks & Dependencies).

**Patterns to follow:** `tests/plasma-taskbar.nix` (materialize-then-grep shape, including the `.data or null` absent-case pattern for `MS-7D91`); the mutation-testing learnings under `.compound-engineering/artifacts/solutions/best-practices/` for how each assertion must be written and verified.

**Test scenarios:**
- Covers R1/R2/R3. Baseline: both ThinkPad configurations render the three logind `Handle*` keys and the Powerdevil `LidAction`/`SleepMode`/`InhibitLidActionWhenExternalMonitorPresent` keys with the values above.
- Covers R4. Negative: `MS-7D91`'s materialized `logind.conf` contains none of the three logind keys, and its `kdePowerLid` activation entry is absent (`null`), not merely empty.
- Mutation coverage (exercised once during implementation, not shipped as an automated suite): flipping any one logind or Powerdevil value on the ThinkPad turns the check red; moving the Powerdevil unit's `lib.mkIf` condition to always-true (simulating a scoping regression that reaches `MS-7D91`) turns the check red; removing the logind settings block turns the check red without an evaluator abort (the `environment.etc` entry stays present with `KillUserProcesses=false` and no `Handle*` keys, so the failure surfaces inside the builder, not at evaluation).

**Verification:** `nix build --no-link .#checks.x86_64-linux.logind-lid-switch` is green on the unmutated tree and turns red under each mutation above (confirm once, then revert); `nix flake check` and `nix fmt -- --ci` pass.

---

## Verification Contract

| Command | Applies to |
|---|---|
| `nix fmt -- --ci` | Whole repo |
| `nix flake check` | All declared checks, including the new `logind-lid-switch` |
| `nix build --no-link .#checks.x86_64-linux.logind-lid-switch` | U1, U2, U3, plus the mutation-testing pass |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | U1, U2, U3 |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | U1, U2, U3 |

Hardware verification (lid actually suspends/hibernates on battery and is ignored on AC/with an external monitor; session-restore is not expected; the swapfile holds a full hibernation image) is out of reach for these commands and is recorded in `docs/verification.md` per U3, reported separately from the above.

## Definition of Done

- U1, U2, and U3 are all implemented and committed.
- All five commands in the Verification Contract pass.
- `docs/verification.md` carries the new check's description and the hardware checklist items from U3.
- No abandoned or experimental code from any unit remains in the diff.
