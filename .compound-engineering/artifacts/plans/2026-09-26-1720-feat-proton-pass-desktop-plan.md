---
title: Proton Pass Desktop - Plan
type: feat
date: 2026-09-26
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Proton Pass Desktop - Plan

## Goal Capsule

- **Objective:** On both production machines, the Proton Pass desktop app is installed and already running when a Plasma session starts, next to 1Password.
- **Means:** Install `proton-pass` as a Home Manager user package and add a forced autostart entry beside the existing ones (KTD1, KTD2).
- **Authority:** Product Contract Requirements win on behavior; KTDs win on mechanism; units override neither.
- **Stop conditions:** Stop if `proton-pass` fails to build on either host, or if adding it forces a `flake.lock` change.
- **Execution profile:** Packaging and config; prove it with the flake check and the four host builds, not runtime tests.
- **Finish and ship:** The implementing agent finishes the work and opens the PR. Hardware verification after `nr` belongs to the user.

## Product Contract

### Summary

Add the Proton Pass desktop app to the user environment on ThinkPad-X1-Carbon-Gen-11 and MS-7D91, and start it at Plasma login on production configurations only. Add no KDE global shortcut.

### Problem Frame

The user wants Proton Pass available alongside 1Password without installing it by hand after every reinstall. Everything else on the desktop is declared in this repository.

### Requirements

**Installation**

- R1. Proton Pass (nixpkgs `proton-pass`) is installed for user `h82` on both production hosts, and 1Password stays as it is.

**Login behavior**

- R2. Proton Pass starts automatically at Plasma login on production configurations.
- R3. Bootstrap configurations declare no Proton Pass autostart entry.

**Shortcuts**

- R4. The change declares no KDE global shortcut. Proton Pass's own in-app shortcuts are the only ones.

### Key Decisions

- **Keep 1Password; add Proton Pass beside it.** (session-settled: user-approved — chosen over replacing 1Password or taking over its Ctrl+Shift+Space: the user picked the option that keeps both apps.) Governs R1.
- **No KDE global shortcut.** (session-settled: user-directed — chosen over a KDE shortcut such as Meta+Shift+P or Ctrl+Shift+Space that launches or focuses proton-pass: the user wants Proton Pass's defaults, and the Linux build registers no global shortcut, so its only built-in one is the in-window Ctrl+Shift+V autotype.) Governs R4.
- **Autostart at login.** (session-settled: user-approved — chosen over installing without autostart: the user picked "install + tray autostart at login".) Governs R2, R3.

### Scope Boundaries

- No KWin window rules, tray tweaks, or browser-extension setup for Proton Pass.
- No systemd restart drop-in. Discord and Telegram have one because they crash. Proton Pass has not shown that problem.

### Sources

- The Proton Pass 1.40.2 `app.asar` has no `globalShortcut` call and no hidden-start argument. It uses a single-instance lock, and a `second-instance` launch shows the existing window. Closing the window hides it to the tray.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Install through `home.packages` in `home/h82/default.nix`.** That list already holds the other user desktop apps (discord, telegram-desktop, kleopatra), and `tests/desktop-autostart.nix` finds packages there by `pname`. A NixOS module would add an option and host wiring for a single package.
- KTD2. **Autostart entry in `home/h82/desktop/kde/autostart.nix`, inside its existing `lib.mkIf (!osConfig.my.bootstrap)`.** Mirror the Discord and Telegram entries: `force = true`, `Hidden=false`, `NoDisplay=true`, `X-KDE-autostart-phase=2`. The Exec line is `${pkgs.proton-pass}/bin/proton-pass` with no arguments, because the Linux build accepts no hidden-start flag. Instantiates the Autostart Key Decision (R2, R3).

### Assumptions

- Because there is no hidden-start flag, the Proton Pass window opens once at each login. Closing it sends it to the tray. The user accepted tray behavior, and nothing in the app can suppress that first window.

---

## Implementation Units

### U1. Install Proton Pass and autostart it at login

- **Goal:** Install Proton Pass and start it at Plasma login on production configurations only.
- **Requirements:** R1, R2, R3, R4; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `home/h82/default.nix`, `home/h82/desktop/kde/autostart.nix`, `README.md`.
- **Approach:**
  1. Add `proton-pass` to the alphabetical `with pkgs` list in `home/h82/default.nix`.
  2. Add `xdg.configFile."autostart/proton-pass.desktop"` following the Discord entry's shape (KTD2).
  3. Add Proton Pass to the app list in `README.md`'s declared-software line, next to 1Password.
- **Patterns to follow:** the Discord and Telegram entries in `home/h82/desktop/kde/autostart.nix`.
- **Test scenarios:** covered by U2.
- **Verification:** All four host builds pass, and the production Home Manager generation contains `autostart/proton-pass.desktop`.

### U2. Guard the Proton Pass autostart entry

- **Goal:** Make `desktop-autostart` fail when the Proton Pass entry is missing, broken, or leaks onto bootstrap.
- **Requirements:** R1, R2, R3.
- **Dependencies:** U1.
- **Files:** `tests/desktop-autostart.nix`.
- **Approach:**
  1. Resolve `protonPassPackage` through the existing `userPackage "proton-pass"` helper. Resolve the entry through `entryFor`, by target and not by attribute name.
  2. Reuse `packageAbsent`, `missing`, and `present` with `Exec=${protonPassPackage}/bin/proton-pass`. Put the store-path interpolation inside an `optionalString` guard, as the existing Exec strings do.
  3. Add `autostart/proton-pass.desktop` to the `bootstrapLeaks` list.
  4. Update the header comment's "Verifies" list.
- **Execution note:** Before trusting the new assertions, mutation-test each one: remove the package, remove the entry, drop `force`, change the Exec path, and move the entry out of the bootstrap guard. Every mutation must fail the check inside the builder, not at evaluation. See `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md` and `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`.
- **Patterns to follow:** the Discord block in `tests/desktop-autostart.nix`.
- **Test scenarios:**
  - When the production host declares the entry with `force`, `Hidden=false`, `Type=Application`, `X-KDE-autostart-phase=2`, and `Exec=<proton-pass store path>/bin/proton-pass`, the check passes.
  - When `proton-pass` is missing from `home.packages`, the check fails with the package-absent message.
  - When the entry is missing, or its `enable` or `force` is false, the check fails.
  - When the Exec line points to a different binary or path, the check fails.
  - When the entry is declared on the bootstrap configuration, the check fails with the leak message.
- **Verification:** `nix build .#checks.x86_64-linux.desktop-autostart` passes on the tree as written, and each mutation above makes it fail.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Formatting | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| Host builds | the four `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` commands in `AGENTS.md` |

Checking on hardware after `nr` (the window appears at login, closing it hides it to the tray) belongs to the user and is reported separately from the build evidence.

## Definition of Done

- R1–R4 hold, and U1 and U2 are complete.
- Every gate in the Verification Contract passes.
- The U2 mutations were each observed to fail the check, and all mutation edits were reverted.
- No leftover experimental code is in the diff.
