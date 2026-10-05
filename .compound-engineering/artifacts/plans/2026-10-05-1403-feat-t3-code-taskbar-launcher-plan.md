---
title: T3 Code Taskbar Launcher - Plan
type: feat
date: 2026-10-05
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# T3 Code Taskbar Launcher - Plan

## Goal Capsule

- **Objective:** On a NixOS host's Plasma desktop, the fourth pinned taskbar launcher opens T3 Code instead of Orca.
- **Means:** swap `applications:orca.desktop` for `applications:t3code.desktop` in the Plasma applets activation script, pinned only when the host enables the T3 Code desktop trait (KTD1).
- **Authority:** this plan, then `AGENTS.md`.
- **Stop conditions:** stop if `t3code.desktop` is not the desktop file the `t3code-desktop` package installs, or if any `nixosConfigurations`, `homeConfigurations`, or `systemConfigs` output stops building.
- **Execution profile:** one small Home Manager change plus its check; `ce-work` implements, LFG ships.

## Product Contract

### Summary

Pin T3 Code in place of Orca on the Plasma task manager, keeping Google Chrome, Dolphin, and Ghostty first in their current order.

### Problem Frame

The user now works in T3 Code rather than Orca, but the taskbar still pins Orca as its fourth launcher. `home/h82/desktop/kde/plasma.nix` writes the pinned list on activation, and `tests/plasma-taskbar.nix` asserts that exact list.

### Requirements

- R1. On a host with `my.t3.desktop.enable` on, the pinned launchers are, in order: `preferred://browser`, `preferred://filemanager`, `applications:com.mitchellh.ghostty.desktop`, `applications:t3code.desktop`.
- R2. No host pins `applications:orca.desktop`.
- R3. A host with the trait off pins only the first three launchers, so no launcher points at an uninstalled desktop file.
- R4. The `plasma-taskbar` check fails when the pinned list differs from R1 or R3, including when Orca is pinned.

### Scope Boundaries

- Orca stays installed; only its taskbar pin is removed.
- Kickoff favorites, task grouping, and the clock settings stay as they are.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Gate the T3 Code launcher on `my.t3.desktop.enable`.** `home/h82/t3code.nix` installs `t3code.desktop` only when the trait is on, so the module reads `config.my.t3.desktop.enable`, as Home Manager branches on traits through `config.my.*`.
- KTD2. **Cover both trait states with `configurations.withTrait`.** Every host enables the trait today, so the check adds the forced-off production configurations, as `tests/t3code-traits.nix` does.

### Assumptions

- `t3code.desktop` is the desktop-file ID: `packages/t3code.nix` installs `$out/share/applications/t3code.desktop` with `install -D`, which fails the build if the AppImage does not ship that file.

---

## Implementation Units

### U1. Pin T3 Code instead of Orca

- **Goal:** the activation script writes the T3 Code launcher in place of Orca.
- **Requirements:** R1, R2, R3, R4; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/desktop/kde/plasma.nix`, `tests/plasma-taskbar.nix`.
- **Approach:**
  1. Drop `applications:orca.desktop` from `pinnedLaunchers` and append `applications:t3code.desktop` only when `config.my.t3.desktop.enable` is on.
  2. In the check, derive each entry's expected list from its trait value, assert it on every configuration plus `withTrait`'s forced-off ones, and splice in the trait guard.
- **Patterns to follow:** the existing per-entry `grep -Fq` assertions in `tests/plasma-taskbar.nix`, and the trait split in `tests/t3code-traits.nix`.
- **Test scenarios:**
  - Every configuration with the trait on, production and bootstrap: the script contains `--key launchers "preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:t3code.desktop"`.
  - Each production configuration with the trait forced off: the script contains the three-launcher list without `t3code.desktop`.
  - Any Orca pin fails the exact launchers match.
  - Grouping stays `groupingStrategy 0` (existing assertion kept).
- **Verification:** `plasma-taskbar` builds green. Pinning Orca, pinning T3 Code unconditionally, or never pinning it each turns it red.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Taskbar check | `nix build --no-link .#checks.x86_64-linux.plasma-taskbar` |
| Mutation proof | each mutation in U1 Verification fails the taskbar check, then is reverted |
| Full checks | `nix flake check` |
| Host outputs | build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output, production and bootstrap, per the loop in `AGENTS.md` |

## Definition of Done

- R1 to R4 hold and every gate in the Verification Contract passes.
- No mutation or experiment code is left in the diff.
