---
title: Winbox Package - Plan
type: feat
date: 2026-10-06
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Winbox Package - Plan

## Goal Capsule

- **Objective:** On a NixOS host, the user can open WinBox from the Plasma application launcher or the shell, find MikroTik routers on the local network, and connect to them by IP or MAC address.
- **Means:** enable the nixpkgs NixOS module `programs.winbox` with `openFirewall` on every NixOS host (KTD1).
- **Authority:** this plan, then `AGENTS.md`, then issue #71.
- **Stop conditions:** stop if `pkgs.winbox` fails to build on x86_64-linux, or if any `nixosConfigurations`, `homeConfigurations`, or `systemConfigs` output stops building.
- **Execution profile:** one NixOS module, one check, and one check-list entry; `ce-work` implements, LFG ships.

## Product Contract

### Summary

Install WinBox on every NixOS host and open the firewall ports WinBox needs for MikroTik neighbor discovery and MAC-address connections.

### Problem Frame

The user manages MikroTik routers with WinBox. The legacy dotfiles installed it (`home/.chezmoiexternals/system.toml` in hyperlapse122/dotfiles), but this flake does not, so it is missing after the migration. Issue #71 tracks the gap. The NixOS firewall is on for every host, so installing the package alone would leave WinBox able to connect by IP only: neighbor discovery and MAC-address connections, which reach a router that has no IP or was just reset, need inbound UDP.

### Requirements

**Application**

- R1. Every NixOS host installs `pkgs.winbox`, so its `winbox.desktop` entry is in the launcher and its `WinBox` executable is on PATH. The command is case-sensitive `WinBox`; it satisfies issue #71's "winbox on PATH" criterion, and no lowercase alias is added.
- R2. No non-NixOS host installs `winbox`, matching the rule that GUI applications apply to NixOS hosts only.

**Network**

- R3. Every NixOS host's firewall accepts the WinBox ports: UDP 5678 for MikroTik Neighbor Discovery, UDP 20561 for MAC-address connections, and UDP 40000-50000.

### Key Decisions

- **Open the WinBox firewall ports on every NixOS host** (session-settled: user-directed — chosen over installing the package only and over a per-host trait: the user wants neighbor discovery and MAC-address connections everywhere). Governs R3.

### Scope Boundaries

- No custom desktop entry, wrapper, or autostart; the nixpkgs derivation ships `share/applications/winbox.desktop`.
- No taskbar pin or Kickoff favorite.
- No `my.*` trait for WinBox; every NixOS host gets it.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use the nixpkgs `programs.winbox` module instead of `home.packages`.** It installs the package system-wide and, with `openFirewall = true`, adds exactly the R3 ports, so one option covers R1 and R3 (session-settled: user-directed — chosen over a `home.packages` entry plus hand-written firewall ports: the user picked `programs.winbox` with `openFirewall`). Governs R1, R3.
- KTD2. **Put it in its own module under `modules/nixos/desktop/` and import it from `modules/nixos/profile.nix`.** Every NixOS host takes the shared profile, and WinBox is a desktop application; a NixOS module never reaches a non-NixOS host, which keeps R2 by construction.
- KTD3. **Check the materialized output.** A new `tests/winbox.nix` reads the built system path and the firewall start script on every configuration from `tests/lib/configurations.nix`, as `tests/printing.nix` does for UDP 5353, rather than the options the module sets. It reads host generations, so it joins `hostClosureChecks` in `flake.nix`.
- KTD4. **Extend the non-NixOS GUI leak list.** Adding `"winbox"` to `guiPackages` in `tests/non-nixos-outputs.nix` makes the existing check fail if WinBox ever lands in a non-NixOS host's Home Manager packages (R2).

### Assumptions

- Every NixOS host is x86_64-linux today (ThinkPad X1 Carbon Gen 11, MS-7D91); nixpkgs builds `winbox` for `x86_64-linux` and `aarch64-darwin` only.
- `allowUnfree = true` is already set in `flake.nix`, `lib/linux-host.nix`, and `modules/nixos/system/base.nix`; `winbox` is unfree and needs no new policy.
- The pinned nixpkgs `winbox` 4.4 installs `bin/WinBox` and `share/applications/winbox.desktop`, and its `programs.winbox.openFirewall` opens UDP 5678, 20561, and 40000-50000.

---

## Implementation Units

### U1. Enable WinBox on NixOS hosts

- **Goal:** every NixOS host installs WinBox and opens its firewall ports.
- **Requirements:** R1, R2, R3; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `modules/nixos/desktop/winbox.nix` (new), `modules/nixos/profile.nix`.
- **Approach:**
  1. Create `modules/nixos/desktop/winbox.nix` setting `programs.winbox.enable` and `programs.winbox.openFirewall`.
  2. Import it from `modules/nixos/profile.nix` beside the other desktop modules.
- **Patterns to follow:** `modules/nixos/system/nix-ld.nix`, a one-program module with no trait.
- **Test scenarios:** covered by U2.
- **Verification:** both NixOS host generations build.

### U2. Check WinBox on every configuration

- **Goal:** a check fails when WinBox or its firewall ports go missing from any NixOS configuration, or when WinBox reaches a non-NixOS host.
- **Requirements:** R1, R2, R3; KTD3, KTD4.
- **Dependencies:** U1.
- **Files:** `tests/winbox.nix` (new), `tests/non-nixos-outputs.nix`, `flake.nix`.
- **Approach:**
  1. Write `tests/winbox.nix` over `configurations.entries`, splicing `configurations.guard`, collecting every failure before exiting.
  2. Per configuration, assert that `config.system.path` carries `bin/WinBox` and `share/applications/winbox.desktop`, and that the firewall start script from the materialized `firewall.service` accepts UDP 5678, UDP 20561, and the UDP range 40000:50000.
  3. Register `winbox` under `checks` in `flake.nix` and add it to `hostClosureChecks`.
  4. Add `"winbox"` to `guiPackages` in `tests/non-nixos-outputs.nix`.
- **Patterns to follow:** the firewall-script read in `tests/printing.nix`; the per-entry `fail` accumulation in `tests/nix-ld.nix`.
- **Execution note:** mutation-test the new check per the repository's mutation-testing learnings: removing the U1 import, or setting `openFirewall = false`, must fail it.
- **Test scenarios:**
  - Each production and bootstrap configuration passes with U1 in place.
  - Without the U1 import, every configuration reports a missing `WinBox` and missing ports.
  - With `openFirewall = false`, every configuration reports the missing UDP 5678, 20561, and 40000:50000 rules, and the package assertions still pass.
  - The x86_64 non-NixOS fixture host's `home.packages` has no `winbox`, and `non-nixos-outputs` passes.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.winbox` passes, and the two mutations fail it.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| New check | `nix build --no-link .#checks.x86_64-linux.winbox` |
| Shard coverage | `check-shards-guard` passes inside `nix flake check` |
| NixOS hosts | `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` for every output, production and bootstrap |
| Non-NixOS outputs | build every `homeConfigurations` and `systemConfigs` output (empty while `hosts/` has no non-NixOS host) |

VM tests are unaffected, but AGENTS.md asks for `nix build --no-link .#vmChecks.all` before shipping when `/dev/kvm` is available.

## Definition of Done

- R1, R2, and R3 hold, shown by `tests/winbox.nix` and `non-nixos-outputs`.
- The mutations in U2 fail the new check.
- Every gate in the Verification Contract passes.
- The diff carries no leftover experimental code.
