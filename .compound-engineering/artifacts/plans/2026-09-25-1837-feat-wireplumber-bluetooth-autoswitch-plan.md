---
title: Disable WirePlumber Bluetooth headset autoswitch - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Disable WirePlumber Bluetooth headset autoswitch - Plan

## Goal Capsule

- **Objective:** On both machines, Bluetooth headphones keep high-quality A2DP stereo playback when an application opens a microphone stream, instead of dropping to mono HFP/HSP.
- **Means:** A shared NixOS module sets `bluetooth.autoswitch-to-headset-profile = false` through `services.pipewire.wireplumber.extraConfig`, guarded by a flake check on the rendered WirePlumber config (KTD1, KTD2, KTD3).
- **Authority:** Issue #58, then this plan's R-IDs, then KTDs.
- **Execution profile:** Lightweight. Two units, one commit each or one combined commit.
- **Stop conditions:** Stop if the rendered fragment does not reach the WirePlumber user service's `XDG_DATA_DIRS`, or if a host build fails.
- **Finish and ship:** `ce-work` implements. The LFG pipeline reviews, opens the PR, and watches CI.

---

## Product Contract

### Summary

Every host configuration ships a WirePlumber config fragment that turns off automatic switching to the Bluetooth headset profile. A new flake check reads the fragment WirePlumber actually loads, for all four host configurations.

### Problem Frame

WirePlumber 0.5 defaults `bluetooth.autoswitch-to-headset-profile` to `true`. When any application opens an input stream (a browser tab probing the microphone, a call client idling), a connected Bluetooth headset switches from A2DP to HFP/HSP, and playback drops to low-bitrate mono. The legacy dotfiles disabled this with `home/dot_config/wireplumber/wireplumber.conf.d/51-disable-bt-autoswitch.conf`. This flake never carried it over. Both hosts enable `hardware.bluetooth.enable`, and WirePlumber runs with an empty `extraConfig` today.

### Requirements

- R1. Every host configuration (ThinkPad-X1-Carbon-Gen-11, its bootstrap, MS-7D91, its bootstrap) makes WirePlumber load `wireplumber.settings` with `bluetooth.autoswitch-to-headset-profile` set to `false`.
- R2. No WirePlumber config fragment the flake ships sets `bluetooth.autoswitch-to-headset-profile` to `true`.
- R3. A flake check registered in `flake.nix` fails when R1 or R2 does not hold for any of the four host configurations.

### Scope Boundaries

- No change to Bluetooth codec, role, or `hfphsp-backend` settings. The headset profile stays available for manual selection in the Plasma audio applet.
- Persistent WirePlumber settings saved by `wpctl settings --save` in `~/.local/state/wireplumber/` are user state and are not managed here.
- Hardware confirmation that A2DP holds while a microphone stream is open follows `docs/verification.md` after a user-run rebuild. It is not part of this change's automated evidence.

### Sources

- Issue: <https://github.com/hyperlapse122/nix-config/issues/58>
- nixpkgs `nixos/modules/services/desktops/pipewire/wireplumber.nix`: `extraConfig` entries render as `share/wireplumber/wireplumber.conf.d/<name>.conf` in a `wireplumber-configs` env. Each section is written as `<section> = <JSON>`. That env reaches `systemd.user.services.wireplumber.environment.XDG_DATA_DIRS` when PipeWire is not system-wide.
- WirePlumber 0.5.17 `share/wireplumber/wireplumber.conf`: the settings schema declares `bluetooth.autoswitch-to-headset-profile` with `default = true`.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **NixOS module, not Home Manager.** Put the setting in a new `modules/nixos/hardware/bluetooth-audio.nix` and import it from both `hosts/*/default.nix`. The nixpkgs `extraConfig` option is the supported route and lands in the service's search path, so no user-level `xdg.configFile` is needed. It also covers the bootstrap generations, which share the host imports. The `hardware/` domain already holds per-device modules such as `sennheiser-btd.nix`.
- KTD2. **Name the fragment `51-disable-bt-autoswitch`.** This matches the legacy dotfiles file name and sorts after WirePlumber's own defaults. The key is a dotted name inside the `wireplumber.settings` section, so the Nix attribute must be quoted as `"bluetooth.autoswitch-to-headset-profile"`.
- KTD3. **Assert on the rendered fragment WirePlumber loads, not the option value.** Per `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, the check starts from `systemd.user.services.wireplumber` for each host. It fails if that service is disabled. It then walks the `XDG_DATA_DIRS` entries of its environment and inspects every `share/wireplumber/wireplumber.conf.d/*.conf` file there. It requires a `wireplumber.settings` line that carries `"bluetooth.autoswitch-to-headset-profile":false`. It fails if any fragment carries the key set to `true` in either syntax: the compact JSON `extraConfig` writes (`"key":true`) or the SPA-JSON a `configPackages` fragment uses (`key = true`). Match the key quoted or unquoted, followed by `:` or `=`, optional whitespace, and `true`. It does not assume a fragment file name, so renaming the entry does not break the guard. Each failure uses an explicit `if ...; then exit 1; fi`. Store paths come from the evaluated environment. Avoid unguarded interpolation that would turn a mutation into an evaluation error, per `unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.

### Assumptions

- WirePlumber 0.5 merges `wireplumber.settings` objects across conf.d fragments, so the fragment overrides only this key and keeps the other defaults. Hardware confirmation settles this.
- PipeWire stays per-user (`services.pipewire.systemWide = false`). If it moves system-wide, the check's service lookup has to follow `systemd.services.wireplumber` instead.

### Risks

- A value saved earlier with `wpctl settings --save bluetooth.autoswitch-to-headset-profile true` persists in user state and overrides config. Hardware verification should check `wpctl settings bluetooth.autoswitch-to-headset-profile` on each host.

---

## Implementation Units

### U1. Add the Bluetooth audio module

- **Goal:** Render R1 on every host configuration.
- **Requirements:** R1, R2. KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `modules/nixos/hardware/bluetooth-audio.nix`, `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, `hosts/MS-7D91/default.nix`.
- **Approach:**
  1. Create the module with one `services.pipewire.wireplumber.extraConfig."51-disable-bt-autoswitch"` entry. It sets the `wireplumber.settings` section to `{ "bluetooth.autoswitch-to-headset-profile" = false; }`.
  2. Add a short comment on why (A2DP drops to mono HFP when a microphone stream opens).
  3. Import it from both host `default.nix` files beside the other `hardware/` modules.
- **Patterns to follow:** `modules/nixos/hardware/sennheiser-btd.nix` for module shape and comment density.
- **Test expectation:** covered by U2's check.
- **Verification:** All four host toplevels build, and `nix fmt -- --ci` passes.

### U2. Add the WirePlumber Bluetooth flake check

- **Goal:** Fail the build when any host stops loading the autoswitch-off setting (R3).
- **Requirements:** R3. KTD3.
- **Dependencies:** U1.
- **Files:** `tests/wireplumber-bluetooth.nix`, `flake.nix`.
- **Approach:**
  1. Mirror `tests/kernel-sysctl.nix`: take `{ pkgs, self }`, define an `assertHost` helper, and run it for the four host configurations inside one `pkgs.runCommand`.
  2. Per host, fail if `systemd.user.services.wireplumber.enable` is false. Then split its `XDG_DATA_DIRS` and scan every `wireplumber/wireplumber.conf.d/*.conf` under those entries.
  3. Require at least one `wireplumber.settings` line with the key at `false`, and no fragment with the key at `true` in either JSON or SPA-JSON form (KTD3).
  4. Register it as `wireplumber-bluetooth` beside `kernel-sysctl` in `flake.nix`.
- **Patterns to follow:** `tests/kernel-sysctl.nix` for structure and the header comment block.
- **Test scenarios:**
  - Happy path: all four hosts load the fragment with `false`, and the check builds.
  - Error path: changing the value to `true` in `bluetooth-audio.nix` fails the check on every host, with the check's own message.
  - Error path: removing the import from `hosts/MS-7D91/default.nix` fails the check on MS-7D91 and MS-7D91-bootstrap only.
  - Error path: setting `systemd.user.services.wireplumber.enable = lib.mkForce false` fails the check. A plain `false` conflicts with the nixpkgs definition and fails during evaluation instead.
  - Edge case: renaming the fragment entry (for example to `60-bt`) still passes, because the check does not rely on the file name.
  - Error path: adding a second `extraConfig` fragment that sets the key to `true` fails the check.
  - Error path: adding a `configPackages` fragment written in SPA-JSON (`wireplumber.settings = { bluetooth.autoswitch-to-headset-profile = true }`) fails the check.
- **Verification:** `nix build .#checks.x86_64-linux.wireplumber-bluetooth` passes on the real config. Each mutation above fails inside the builder with the check's message, not during evaluation. Revert every mutation afterward.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.wireplumber-bluetooth` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, MS-7D91-bootstrap |

Hardware confirmation (`wpctl settings bluetooth.autoswitch-to-headset-profile` reports `false`, and a connected headset stays on A2DP while a microphone stream is open) happens after a user-run rebuild. Report it separately from build evidence, per `docs/verification.md`.

## Definition of Done

- U1 and U2 landed. The check passes on the real configuration and fails under each U2 error-path mutation.
- `nix fmt -- --ci`, `nix flake check`, and all four host builds pass.
- No mutation or experiment code remains in the diff.
