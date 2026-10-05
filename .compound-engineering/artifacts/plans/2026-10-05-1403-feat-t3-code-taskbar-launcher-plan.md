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
- **Means:** swap `applications:orca.desktop` for `applications:t3code.desktop` in the Plasma applets activation script (KTD1).
- **Authority:** this plan, then `AGENTS.md`.
- **Stop conditions:** stop if `t3code.desktop` is not the desktop file the `t3code-desktop` package installs, or if any `nixosConfigurations`, `homeConfigurations`, or `systemConfigs` output stops building.
- **Execution profile:** one small Home Manager change plus its check; `ce-work` implements, LFG ships.

## Product Contract

### Summary

Pin T3 Code in place of Orca on the Plasma task manager, keeping Google Chrome, Dolphin, and Ghostty first in their current order.

### Problem Frame

The user now works in T3 Code rather than Orca, but the taskbar still pins Orca as its fourth launcher. `home/h82/desktop/kde/plasma.nix` writes the pinned list on activation, and `tests/plasma-taskbar.nix` asserts that exact list.

### Requirements

- R1. The pinned launchers are, in order: `preferred://browser`, `preferred://filemanager`, `applications:com.mitchellh.ghostty.desktop`, `applications:t3code.desktop`.
- R2. No host pins `applications:orca.desktop`.
- R3. The `plasma-taskbar` check fails when the pinned list differs from R1 or when Orca is pinned.

### Scope Boundaries

- Orca stays installed; only its taskbar pin is removed.
- Kickoff favorites, task grouping, and the clock settings stay as they are.
- Considered and not built: gating the T3 Code pin on `my.t3.desktop.enable`. Every NixOS host enables that trait, and a dead launcher on a host that turned it off would be visible at once and cheap to fix. Add the gate if a host ever disables the trait.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Swap the entry in place, unconditionally.** `pinnedLaunchers` keeps its fixed list with `applications:t3code.desktop` in Orca's slot, so the module and its check keep their current shape.

### Assumptions

- `t3code.desktop` is the desktop-file ID: `packages/t3code.nix` installs `$out/share/applications/t3code.desktop` with `install -D`, which fails the build if the AppImage does not ship that file.

---

## Implementation Units

### U1. Pin T3 Code instead of Orca

- **Goal:** the activation script writes the T3 Code launcher in place of Orca.
- **Requirements:** R1, R2, R3; KTD1.
- **Dependencies:** none.
- **Files:** `home/h82/desktop/kde/plasma.nix`, `tests/plasma-taskbar.nix`.
- **Approach:**
  1. Replace `applications:orca.desktop` with `applications:t3code.desktop` in `pinnedLaunchers` and update the inline comment that lists the pinned apps.
  2. Update `expectedLaunchers` and the header comment in the check, and add an assertion that the script contains no `orca.desktop`.
- **Patterns to follow:** the existing per-entry `grep -Fq` assertions in `tests/plasma-taskbar.nix`.
- **Test scenarios:**
  - Every configuration, production and bootstrap: the script contains `--key launchers "preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:t3code.desktop"`.
  - Every configuration: the script does not contain `orca.desktop`.
  - Grouping stays `groupingStrategy 0` (existing assertion kept).
- **Verification:** `plasma-taskbar` builds green, and reverting the module to pin Orca turns it red.

---

## Verification Contract

| Gate | Command |
|---|---|
| Format | `nix fmt -- --ci` |
| Taskbar check | `nix build --no-link .#checks.x86_64-linux.plasma-taskbar` |
| Mutation proof | the Orca-revert mutation in U1 Verification fails the taskbar check, then is reverted |
| Full checks | `nix flake check` |
| Host outputs | build every `nixosConfigurations`, `homeConfigurations`, and `systemConfigs` output, production and bootstrap, per the loop in `AGENTS.md` |

## Definition of Done

- R1 to R3 hold and every gate in the Verification Contract passes.
- No mutation or experiment code is left in the diff.
