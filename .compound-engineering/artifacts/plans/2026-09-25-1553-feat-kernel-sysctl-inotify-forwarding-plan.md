---
title: Kernel sysctl for inotify limits and IP forwarding - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Kernel sysctl for inotify limits and IP forwarding - Plan

## Goal Capsule

- **Objective:** On both machines, IDEs and file watchers keep a high inotify budget, and either host can act as a Tailscale subnet router or exit node without a manual `sysctl` step.
- **Means:** Declare the four sysctl keys in the shared `modules/nixos/system/base.nix` and guard the rendered sysctl file with a flake check (KTD1, KTD3).
- **Authority:** Issue #56, except where the Product Contract Key Decisions supersede it (the `max_user_instances` value), then this plan's R-IDs, then KTDs.
- **Execution profile:** Lightweight. Two units, one commit each or one combined commit.
- **Stop conditions:** Stop if a declared value would lower an effective limit on any host, or if a host build fails from a sysctl option conflict.
- **Finish and ship:** `ce-work` implements. The LFG pipeline reviews, opens the PR, and watches CI.

---

## Product Contract

### Summary

Every host configuration declares explicit inotify limits and enables IPv4 and IPv6 forwarding. A new flake check reads the rendered `/etc/sysctl.d/60-nixos.conf` for all four host configurations and fails if any value is missing or wrong.

### Problem Frame

The legacy dotfiles shipped `99-inotify.conf` and `99-tailscale.conf`. This flake never carried them over. Today the inotify values come only from a nixpkgs `mkDefault`, so a nixpkgs change could silently lower them. Forwarding is on only for MS-7D91, and only as a side effect of `my.tailscale.advertiseRoutes`. The ThinkPad and both bootstrap generations have no forwarding, so the laptop cannot serve as an exit node.

### Requirements

**Inotify limits**

- R1. Every host configuration renders `fs.inotify.max_user_watches=524288`.
- R2. Every host configuration renders an `fs.inotify.max_user_instances` value of at least the current effective 524288 (see KTD2).

**Packet forwarding**

- R3. Every host configuration renders `net.ipv4.ip_forward=1`.
- R4. Every host configuration renders `net.ipv6.conf.all.forwarding=1`.

**Regression guard**

- R5. A flake check registered in `flake.nix` fails when any of R1-R4 does not hold for ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, or MS-7D91-bootstrap.

### Key Decisions

- **Keep `fs.inotify.max_user_instances` at 524288 instead of the issue's 8192.** nixpkgs `nixos/modules/config/sysctl.nix` already sets both inotify keys to `mkDefault 524288`, so 8192 would cut the instance limit 64-fold. That contradicts the issue's own goal of raising limits for concurrent agent and IDE processes. Governs R2.

### Scope Boundaries

- No change to `modules/nixos/services/tailscale.nix`. Its `useRoutingFeatures = "server"` keeps setting `net.ipv4.conf.all.forwarding` and `net.ipv6.conf.all.forwarding` at `mkOverride 97` on MS-7D91.
- No forward-chain firewall filtering. That would be a separate hardening change.
- Runtime `sysctl` confirmation on real hardware follows `docs/verification.md` after a rebuild. It is not part of this change's automated evidence.

### Sources

- Issue: https://github.com/hyperlapse122/nix-config/issues/56
- nixpkgs defaults: `nixos/modules/config/sysctl.nix` (inotify `mkDefault 524288`) and `nixos/modules/services/networking/tailscale.nix` (forwarding at `mkOverride 97`).
- Current evaluated state: MS-7D91 has both inotify keys at 524288 plus `net.ipv4.conf.all.forwarding` and `net.ipv6.conf.all.forwarding` true. The ThinkPad has only the inotify keys.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Declare the keys in `modules/nixos/system/base.nix`.** Both hosts and both bootstrap variants import it, so one declaration covers R1-R4 everywhere. The issue names `modules/nixos/base.nix`, which moved to `modules/nixos/system/` since. After this change `my.tailscale.advertiseRoutes` and `services.tailscale.useRoutingFeatures` no longer decide whether forwarding is on. The ThinkPad `"none"` assertion in `tests/tailscale-provisioning.nix` then covers only reverse-path filtering and route advertisement.
- KTD2. **Use plain priority and integer values for the forwarding keys.** `net.ipv6.conf.all.forwarding` also comes from the tailscale module on MS-7D91 at `mkOverride 97`. The higher-priority `true` wins and renders as `1`, so the merge produces no conflict and the same runtime value. `net.ipv4.ip_forward` is a different key from tailscale's `net.ipv4.conf.all.forwarding`, and the kernel treats them as equivalent.
- KTD3. **Assert on the rendered sysctl file, not the option value.** The check reads `environment.etc."sysctl.d/60-nixos.conf"` for each host and confirms the entry is enabled, following `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`. Each match is anchored to a whole line (`^key=value$`) so a longer value such as `5242880` cannot satisfy it, per `unanchored-grep-fragment-misses-destination-argument.md`. Each failure uses an explicit `if ...; then exit 1; fi`, never a bare `! grep`.

### Assumptions

- The issue's 8192 for `max_user_instances` comes from legacy dotfiles for a non-NixOS distribution, where the kernel default is 128 and 8192 is an increase. On NixOS the effective default is already 524288, so keeping 524288 preserves the issue's intent to raise limits.
- Enabling forwarding on the laptop is accepted as the issue requests. Tailscale exit-node use on the ThinkPad needs it.

### Risks

- The inotify assertions also pass if the base.nix declaration is removed, because the nixpkgs `mkDefault` renders the same values. The check guards the effective value, which is the property that matters. It does not prove the declaration exists. Mutation testing should confirm that changing a declared value (for example `max_user_instances` to 8192) fails the check, and that removing the forwarding keys fails it on the ThinkPad hosts.
- IPv6 forwarding disables kernel router-advertisement acceptance when `accept_ra=1`. NetworkManager handles RA in userspace, so addressing should not change. Confirm on hardware after the rebuild.

---

## Implementation Units

### U1. Declare sysctl keys in the base module

- **Goal:** Render R1-R4 on every host configuration.
- **Requirements:** R1, R2, R3, R4. KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `modules/nixos/system/base.nix`.
- **Approach:** Add one `boot.kernel.sysctl` attribute set with the four keys at plain priority. Add a short comment only for the non-obvious 524288 instance limit (Key Decisions).
- **Patterns to follow:** Existing attribute layout in `modules/nixos/system/base.nix`. Let `nix fmt` settle the layout.
- **Test expectation:** covered by U2's check.
- **Verification:** All four host toplevels build, and `nix fmt -- --ci` passes.

### U2. Add the sysctl flake check

- **Goal:** Fail the build when any host stops rendering R1-R4 (R5).
- **Requirements:** R5. KTD3.
- **Dependencies:** U1.
- **Files:** `tests/kernel-sysctl.nix`, `flake.nix`.
- **Approach:**
  1. Mirror `tests/logitech-wakeup.nix`: take `{ pkgs, self }`, define an `assertHost` helper, and run it for the four host configurations inside one `pkgs.runCommand`.
  2. Per host, fail if `environment.etc."sysctl.d/60-nixos.conf".enable` is false, then grep the rendered file for each expected line anchored with `^...$`.
  3. Register it as `kernel-sysctl` beside `logitech-wakeup` in `flake.nix`.
- **Patterns to follow:** `tests/logitech-wakeup.nix` for structure and the header comment block.
- **Test scenarios:**
  - Happy path: all four hosts render all four lines, and the check builds.
  - Error path: changing `fs.inotify.max_user_instances` to 8192 in base.nix fails the check on every host.
  - Error path: removing `net.ipv4.ip_forward` fails the check on the ThinkPad hosts.
  - Edge case: a value like `fs.inotify.max_user_watches=5242880` does not satisfy the anchored match.
  - Error path: setting the `sysctl.d/60-nixos.conf` etc entry `enable = false` fails the check.
- **Verification:** `nix build .#checks.x86_64-linux.kernel-sysctl` passes on the real config, and each mutation above makes it fail. Revert every mutation afterward.

---

## Verification Contract

| Gate | Command |
|---|---|
| Formatting | `nix fmt -- --ci` |
| New check | `nix build --no-link .#checks.x86_64-linux.kernel-sysctl` |
| All checks | `nix flake check` |
| Host builds | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for ThinkPad-X1-Carbon-Gen-11, ThinkPad-X1-Carbon-Gen-11-bootstrap, MS-7D91, MS-7D91-bootstrap |

Hardware confirmation (`sysctl fs.inotify.max_user_watches` and the other three keys) happens after a user-run rebuild and is reported separately from build evidence, per `docs/verification.md`.

## Definition of Done

- U1 and U2 landed. The check passes on the real configuration and fails under each U2 mutation.
- `nix fmt -- --ci`, `nix flake check`, and all four host builds pass.
- No mutation or experiment code remains in the diff.
- The PR description states the departure from the issue's 8192 for `max_user_instances` and why.
