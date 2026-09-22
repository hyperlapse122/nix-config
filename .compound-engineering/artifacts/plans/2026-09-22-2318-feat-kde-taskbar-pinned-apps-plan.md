---
title: KDE Taskbar Pinned Apps - Plan
type: feat
date: '2026-09-22'
topic: kde-taskbar-pinned-apps
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

## Goal Capsule

- **Objective:** KDE Plasma desktop environment consistently provisions pinned applications on the taskbar in the declared order across rebuilds and machines.
- **Means:** Extend `home.activation.kdePlasmaApplets` in `home/h82/kde/plasma.nix` using `kwriteconfig6` to set the `launchers` key on task manager panel applets (`org.kde.plasma.icontasks` and `org.kde.plasma.taskmanager`) (KTD1).
- **Product Authority:** h82
- **Open Blockers:** None

---

## Product Contract

### Summary

Declare and maintain a consistent list of pinned applications on the KDE Plasma Icons-Only Task Manager panel across NixOS rebuilds, ordered specifically: Google Chrome, Dolphin, Ghostty, and Orca.

### Problem Frame

In the current configuration, `home/h82/kde/plasma.nix` configures task manager grouping and kickoff views, but leaves pinned taskbar launchers unmanaged. Manually pinned applications on the taskbar can resolve to volatile generation-dependent store paths (e.g. `file:///nix/store/...-user-environment/share/applications/orca.desktop`), which break across generations or garbage collection. In addition, new installations or configuration resets fall back to default Plasma icons rather than the user's standard development workflow tools.

### Key Decisions

- **Declarative Taskbar Launchers via kwriteconfig6**: Configure `launchers` under `[Containments][$containment][Applets][$applet][Configuration][General]` dynamically in `home.activation.kdePlasmaApplets` (session-settled: user-directed — chosen over host-specific bifurcation or ad-hoc manual pinning: ensures a clean, declarative default without introducing external flakes like plasma-manager). Governs R1, R2, R4.
- **Stable XDG Application URIs**: Use stable application URIs (`preferred://browser` or `applications:google-chrome.desktop`, `preferred://filemanager` or `applications:org.kde.dolphin.desktop`, `applications:com.mitchellh.ghostty.desktop`, `applications:orca.desktop`) rather than `file:///nix/store/...` paths to ensure durability across NixOS rebuilds and garbage collection. Governs R3.

### Requirements

- R1. The KDE taskbar (`org.kde.plasma.icontasks` or `org.kde.plasma.taskmanager`) must be configured with a declared list of pinned launcher applications.
- R2. The pinned applications must be ordered exactly as: Google Chrome, Dolphin, Ghostty, and Orca.
- R3. Application launcher entries must use stable XDG/KDE service URIs (`preferred://` or `applications:<name>.desktop`) instead of Nix store file paths.
- R4. The configuration must execute during Home Manager activation and apply identically to both ThinkPad and desktop workstation hosts.

### Acceptance Examples

- AE1. Activation writes expected launchers key
  - **Trigger:** `home-manager` activation runs `home.activation.kdePlasmaApplets`.
  - **Covers:** R1, R2, R3, R4
  - **Given:** Plasma applet config exists at `~/.config/plasma-org.kde.plasma.desktop-appletsrc` with an `icontasks` or `taskmanager` containment.
  - **When:** Activation script completes.
  - **Then:** The `launchers` key under `[Containments][$containment][Applets][$applet][Configuration][General]` contains the four declared applications in order: Google Chrome, Dolphin, Ghostty, and Orca.

### Scope Boundaries

- **Deferred for later**:
  - Host-specific overrides for pinned launchers (both hosts share the common launcher list).
  - Declarative management of other panel widgets (system tray, pager, etc.) beyond grouping and kickoff options already present in `plasma.nix`.
- **Outside this product's identity**:
  - Introducing third-party configuration flakes (such as `plasma-manager`) when native `kwriteconfig6` scripts satisfy current needs with lower carrying cost.

### Sources / Research

- `home/h82/kde/plasma.nix`: Existing `home.activation.kdePlasmaApplets` script that discovers containment and applet IDs for `org.kde.plasma.icontasks`.
- `~/.config/plasma-org.kde.plasma.desktop-appletsrc`: Live configuration verifying `launchers` key under `[Containments][2][Applets][5][Configuration][General]`.
- `/etc/profiles/per-user/h82/share/applications/`: Confirms availability of `google-chrome.desktop`, `com.mitchellh.ghostty.desktop`, and `orca.desktop`.
- `/run/current-system/sw/share/applications/`: Confirms availability of `org.kde.dolphin.desktop`.

---

## Planning Contract

Product Contract unchanged.

### Key Technical Decisions

- KTD1. **Extend existing kdePlasmaApplets activation loop**: Configure `launchers` using `kwriteconfig6` directly within the `case "$plugin" in org.kde.plasma.icontasks|org.kde.plasma.taskmanager)` block in `home/h82/kde/plasma.nix`. This modifies the live desktop configuration cleanly on activation without requiring desktop layout recreation. Governs R1, R4.
- KTD2. **Order launchers with canonical KDE desktop service URIs**: Format the `launchers` key value as `"preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:orca.desktop"` (session-settled: user-directed — chosen over host-specific bifurcation or ad-hoc manual pinning: ensures declarative consistency across machines without volatile nix-store file paths). Governs R2, R3.
- KTD3. **Automated regression check in flake.nix**: Add a new check derivation `tests/plasma-taskbar.nix` registered in `flake.nix` under `checks.${system}.plasma-taskbar` to assert that the activation scripts for both `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91` contain the expected `launchers` string.

---

## Implementation Units

### U1. Declarative taskbar launchers in home/h82/kde/plasma.nix

- **Goal:** Add the declared `launchers` configuration to `home.activation.kdePlasmaApplets` in `home/h82/kde/plasma.nix`.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** None
- **Files:**
  - `home/h82/kde/plasma.nix`
- **Approach:**
  1. In `home/h82/kde/plasma.nix`, within the `org.kde.plasma.icontasks|org.kde.plasma.taskmanager)` branch:
  2. Add the `kwrite` command to set `launchers` under group `Containments/$containment/Applets/$applet/Configuration/General` to `"preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:orca.desktop"`.
- **Test scenarios:**
  - **Happy path behaviors:** Run `nix eval .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.home-manager.users.h82.home.activation.kdePlasmaApplets.data` and verify the script contains the `launchers` line.
  - **Integration scenarios:** Run `nix eval .#nixosConfigurations.MS-7D91.config.home-manager.users.h82.home.activation.kdePlasmaApplets.data` and verify the script is identical on the desktop host.
- **Verification:**
  - Both configurations evaluate without error and output the expected `kwriteconfig6` command.

### U2. Regression check in tests/plasma-taskbar.nix and flake.nix

- **Goal:** Prevent future regressions from deleting or changing the pinned launcher configuration.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** U1
- **Files:**
  - `tests/plasma-taskbar.nix`
  - `flake.nix`
- **Approach:**
  1. Create `tests/plasma-taskbar.nix` taking `{ pkgs, self }`.
  2. Extract `home.activation.kdePlasmaApplets.data` for `ThinkPad-X1-Carbon-Gen-11` and `MS-7D91`.
  3. Assert using `pkgs.gnugrep` that both contain:
     `--key launchers "preferred://browser,preferred://filemanager,applications:com.mitchellh.ghostty.desktop,applications:orca.desktop"`.
  4. Register `plasma-taskbar = import ./tests/plasma-taskbar.nix { inherit pkgs self; };` in `flake.nix`.
- **Test scenarios:**
  - Covers AE1.
  - **Happy path behaviors:** `nix build --no-link .#checks.x86_64-linux.plasma-taskbar` succeeds on valid configuration.
  - **Error and failure paths:** If the launchers order is changed or an app is removed, the check fails with exit code 1.
- **Verification:**
  - `nix build --no-link .#checks.x86_64-linux.plasma-taskbar` builds successfully.

---

## Verification Contract

| Command | Purpose |
| --- | --- |
| `nix fmt -- --ci` | Formatting validation |
| `nix build --no-link .#checks.x86_64-linux.plasma-taskbar` | Taskbar launchers regression check |
| `nix flake check` | All flake checks pass |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | ThinkPad host build validation |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | ThinkPad bootstrap build validation |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | MS-7D91 host build validation |
| `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | MS-7D91 bootstrap build validation |

---

## Definition of Done

- All requirements R1–R4 and acceptance example AE1 are satisfied.
- U1 and U2 are implemented and all verification contract commands pass.
- No secrets or unwanted files are left in the git working tree.
