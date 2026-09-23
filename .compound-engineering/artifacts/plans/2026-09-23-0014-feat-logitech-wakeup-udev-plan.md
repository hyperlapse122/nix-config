---
title: Logitech Wireless Receiver Wakeup Disable - Plan
type: feat
date: 2026-09-23
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Logitech Wireless Receiver Wakeup Disable - Plan

## Goal Capsule

- **Objective:** Logitech Unifying and Logi Bolt wireless USB receivers never wake either host from system suspend.
- **Means:** A udev rule in the common NixOS base module sets `power/wakeup=disabled` on the two receiver device IDs (KTD1).
- **Authority hierarchy:** [Issue #53](https://github.com/hyperlapse122/nix-config/issues/53) is authoritative for the exact rule text and device IDs; `AGENTS.md` governs module placement and check conventions.
- **Stop conditions:** None — the change is additive, does not touch boot, secrets, or authentication paths.
- **Execution profile:** Lightweight, code.
- **Who finishes and ships:** `ce-work` implements and verifies by build/check; hardware wake-behavior confirmation is a manual follow-up, out of this plan's automated scope.

---

## Product Contract

### Summary

Add a udev rule that disables USB remote wakeup for the Logitech Unifying receiver (`046d:c52b`) and Logi Bolt receiver (`046d:c548`) on both NixOS hosts, ported from the user's legacy dotfiles rule, so these receivers can no longer spuriously wake the system from suspend.

### Problem Frame

The user's pre-NixOS dotfiles already solved this with an explicit udev rule (`system/linux/etc/udev/rules.d/79-logitech-receiver.rules`); that fix has not yet been carried into this flake, so the wakeup behavior it prevented is currently unguarded on both hosts.

### Requirements

- R1. When a Logitech Unifying receiver (`idVendor` `046d`, `idProduct` `c52b`) is added, the system sets its `power/wakeup` attribute to `disabled`.
- R2. When a Logi Bolt receiver (`idVendor` `046d`, `idProduct` `c548`) is added, the system sets its `power/wakeup` attribute to `disabled`.
- R3. The rule is provisioned on both `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91`, including their bootstrap variants, via one common module.
- R4. `nix fmt -- --ci` and `nix flake check` pass, and all four host builds succeed.

### Scope Boundaries

- **Deferred to Follow-Up Work:** the custom haptic feedback daemon (`mxm4-haptic`) integration present in the legacy dotfiles rule — issue #53 explicitly omits it from this migration.
- **Out of scope:** wakeup handling for any USB device other than the two named receiver IDs.

### Key Decisions

- **Use the exact udev rule from issue #53** (`ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled"`). Governs R1, R2. (session-settled: user-directed — chosen over a systemd sleep hook or a runtime script toggling `/sys/bus/usb/devices/*/power/wakeup`: issue #53 specifies this exact declarative rule, carried over from the user's own working legacy dotfiles.)
- **Limit scope to the two named receiver device IDs and omit the haptic daemon.** Governs R1, R2, and the Scope Boundaries entry above. (session-settled: user-directed — chosen over porting the haptic daemon trigger alongside the wakeup rule: issue #53 explicitly states it is omitted from scope.)
- **Place the rule in common module configuration, not per-host.** Governs R3. (session-settled: user-directed — chosen over duplicating the rule under `hosts/*/`: issue #53 names common desktop/system configuration as the target so both hosts share one definition.)

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Author the rule in `modules/nixos/base.nix`, not `desktop.nix`.** `base.nix` is the host-agnostic system module both `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` and `hosts/MS-7D91/default.nix` import unconditionally, alongside `desktop.nix` — neither import is gated behind `config.my.bootstrap`, so either file reaches all four host configurations equally. `desktop.nix`'s existing content (SDDM, Plasma, fcitx5, KDE `environment.etc` files) is exclusively Plasma-desktop-shell configuration; a USB power-management rule is a hardware/system concern, not a desktop-shell one. Keeping it in `base.nix` preserves `desktop.nix` as a single-concern module per `AGENTS.md`.
- KTD2. **Guard the rule with a flake check that reads the materialized `services.udev.extraRules` value from each evaluated host, not a static string in the module source.** No other module currently sets `services.udev.extraRules` (repo-wide search found none), so an assertion reading `host.config.services.udev.extraRules` is not a constant: removing U1's line changes the merged value the check observes. Follow the existing `claude-desktop`/`orca-desktop` `assertHost`-per-host pattern in `flake.nix`, asserting on all four hosts (`ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`) since nothing gates the option between production and bootstrap. This follows this repo's captured checks discipline: assert the materialized option value reaching the built system, not a proxy for it, and assert every host the option should hold on (see Sources & Research).

### Assumptions

- The bootstrap host variants (`ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91-bootstrap`) should carry the same rule as their production counterparts, since neither `base.nix` import is conditioned on `config.my.bootstrap` and the issue does not ask for bootstrap exclusion.

---

## Implementation Units

### U1. Add the udev wakeup-disable rule to `base.nix`

- **Goal:** Declare `services.udev.extraRules` in `modules/nixos/base.nix` with the exact rule text from R1/R2.
- **Requirements:** R1, R2, R3 (KTD1)
- **Dependencies:** none
- **Files:** `modules/nixos/base.nix`
- **Approach:**
  - Add `services.udev.extraRules = '' ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c52b|c548", ATTR{power/wakeup}="disabled" '';` at the top level of the module's attribute set, matching the rule text verbatim from issue #53 (KTD1).
- **Test scenarios:**
  - Test expectation: none -- a single-line declarative config addition with no branching logic; correctness is proven by U2's flake check reading the materialized option value across all four hosts, not by a standalone test for this unit.
- **Verification:** `nix fmt -- --ci` and `nix flake check` pass; U2's `logitech-wakeup` check passes once both units land.

### U2. Add and register the `logitech-wakeup` regression check

- **Goal:** Guard the rule against removal, accidental host-gating, or corruption by asserting the merged `services.udev.extraRules` value on all four host configurations.
- **Requirements:** R3, R4 (KTD2)
- **Dependencies:** U1
- **Files:** `tests/logitech-wakeup.nix` (new), `flake.nix` (register the check)
- **Approach:**
  1. Follow the `tests/plasma-taskbar.nix` / `flake.nix` `claude-desktop` check shape: a `{ pkgs, self }:` interface, `pkgs.runCommand` with `set -x`, one `assertHost` helper called once per host.
  2. For each of `ThinkPad-X1-Carbon-Gen-11`, `ThinkPad-X1-Carbon-Gen-11-bootstrap`, `MS-7D91`, `MS-7D91-bootstrap`, write `host.config.services.udev.extraRules` to a file with `pkgs.writeText` and assert with `grep -Fq` that it contains the exact rule line from U1 (KTD2); fail with an explicit `echo ... >&2; exit 1` naming the host when absent.
  3. Register `logitech-wakeup = import ./tests/logitech-wakeup.nix { inherit pkgs self; };` in `flake.nix`'s `checks` attribute set, near the other host-hardware checks (e.g. beside `plasma-taskbar`).
- **Test scenarios:**
  - Given all four host configurations, when the check evaluates `services.udev.extraRules`, then it contains the exact `ACTION`/`SUBSYSTEM`/`DRIVERS`/`ATTRS`/`ATTR` rule line for every host.
  - Given the rule line removed from `base.nix` (mutation), when the check runs, then it fails **inside the builder**, naming the host and the missing rule -- not merely a Nix evaluation error.
  - Given one product ID mistyped (e.g. `c52b` -> `c52a`), when the check runs, then it fails, since the exact-string assertion no longer matches.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.logitech-wakeup` passes on the unmutated tree. Before declaring this unit done, mutate locally per the two scenarios above and confirm the check fails inside the builder (read `nix log` for the failing derivation, not just the exit code) -- this repository's established mutation-testing discipline for new checks (see Sources & Research).

---

## Verification Contract

| Command | Purpose |
| --- | --- |
| `nix fmt -- --ci` | Formatting check, no diffs |
| `nix flake check` | Runs all declared checks, including `logitech-wakeup` |
| `nix build --no-link .#checks.x86_64-linux.logitech-wakeup` | The new regression check in isolation |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Host build |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap host build |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | Host build |
| `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | Bootstrap host build |

## Definition of Done

- All four host builds succeed; `nix fmt -- --ci` and `nix flake check` pass.
- The `logitech-wakeup` check is registered in `flake.nix`, passes on the unmutated tree, and was locally verified (before commit) to fail when the rule line is removed or a device ID is mistyped, per this repo's mutation-testing discipline for new checks.
- No leftover experimental or dead-end code from either unit.
- Hardware verification (a connected receiver's `/sys/bus/usb/devices/*/power/wakeup` reads `disabled`, and it no longer wakes the host) is explicitly out of this plan's automated scope. Record it as a manual follow-up per `docs/verification.md`, reported separately from build/check evidence per `AGENTS.md`.

## Sources & Research

- [Issue #53](https://github.com/hyperlapse122/nix-config/issues/53) — exact rule text, device IDs, and scope exclusions.
- `modules/nixos/base.nix`, `modules/nixos/desktop.nix` — read to confirm module placement (KTD1): `base.nix` is host-agnostic; `desktop.nix` is exclusively Plasma-shell configuration.
- `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, `hosts/MS-7D91/default.nix` — confirm both hosts import `base.nix` and `desktop.nix` unconditionally, with no `config.my.bootstrap` gating around either import.
- `tests/plasma-taskbar.nix`, and the `claude-desktop` / `orca-desktop` checks in `flake.nix` — existing per-host `assertHost` check pattern followed by U2.
- `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, `.../mutation-testing-reveals-decorative-nix-check-assertions.md`, `.../nix-check-assertion-on-unconditional-option-folds-to-a-constant.md` — guard the new check against reading a proxy value or an operand no mutation of the code under test can change (KTD2).
