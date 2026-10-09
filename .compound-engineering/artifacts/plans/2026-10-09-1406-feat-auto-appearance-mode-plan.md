---
title: Automatic Light/Dark Appearance on macOS and KDE - Plan
type: feat
date: 2026-10-09
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Automatic Light/Dark Appearance on macOS and KDE - Plan

## Goal Capsule

- **Objective:** Both desktops the flake manages, macOS and Plasma on NixOS, switch between light and dark on their own with the time of day, the "자동" (Auto) choice in macOS System Settings > Appearance.
- **Means:** Set `system.defaults.NSGlobalDomain.AppleInterfaceStyleSwitchesAutomatically` in `modules/darwin/defaults.nix`. Turn on Plasma's built-in `lookandfeelautoswitcher` through `[KDE] AutomaticLookAndFeel` in `/etc/xdg/kdeglobals` and in the user's `kdeglobals`. Stop the `kdeTheme` activation from forcing Breeze Light (U1-U4).
- **Authority:** The Key Decisions below win over this plan's own choices; Key Technical Decisions win on mechanism.
- **Execution profile:** Small Nix edits plus check updates. Verify on the Mac by evaluating check build scripts and building `darwin-outputs`; CI's check shards and `build-darwin` build the rest.
- **Stop conditions:** Stop if the pinned Plasma no longer ships `lookandfeelautoswitcher` or no longer reads `AutomaticLookAndFeel` from `[KDE]` in `kdeglobals`, or if nix-darwin drops `AppleInterfaceStyleSwitchesAutomatically`.
- **Finish:** The implementer ships the PR. The user does the hardware checks (`nr switch` on the Mac, a rebuild and login on the NixOS desktop).

## Product Contract

### Summary

Set both desktops to automatic appearance: macOS through its own Auto setting, and Plasma through its built-in day/night global-theme switcher between Breeze Light and Breeze Dark.

### Problem Frame

The user's screenshot shows macOS System Settings > Appearance on "라이트" (Light), and the user wants "자동" (Auto). `modules/darwin/defaults.nix` declares no system defaults yet. On NixOS, Plasma is pinned to Breeze Light twice: `/etc/xdg/kdeglobals` (`modules/nixos/desktop/desktop.nix`) carries the Breeze Light identity and colors, and the `kdeTheme` Home Manager activation (`home/h82/desktop/kde/theme.nix`) writes the Breeze Light identity and every color entry into the user's `kdeglobals` whenever the Home Manager generation changes. Neither desktop follows the time of day.

### Requirements

**macOS**

- R1. Every macOS host output, production and bootstrap, sets `AppleInterfaceStyleSwitchesAutomatically` to true in the global domain and does not set `AppleInterfaceStyle`.

**KDE Plasma (NixOS hosts)**

- R2. `/etc/xdg/kdeglobals` turns on `[KDE] AutomaticLookAndFeel` with `DefaultLightLookAndFeel=org.kde.breeze.desktop` and `DefaultDarkLookAndFeel=org.kde.breezedark.desktop`, so every Plasma user starts in automatic mode.
- R3. After the `kdeTheme` activation, h82's effective `kdeglobals` values have automatic switching on with the same light and dark packages, even when the user file had turned it off or named other packages.
- R4. The activation no longer forces the Breeze Light identity or colors into the user file, so a rebuild at night does not switch a dark session back to light.
- R5. Breeze Light remains the system baseline in `/etc/xdg/kdeglobals` (identity and color groups), used before the switcher first runs.

**Checks**

- R6. The checks fail when any of R1-R5 regresses.

### Key Decisions

- **Auto mode on both desktops.** (session-settled: user-directed — chosen over a fixed light or dark appearance: the user picked the "자동" option shown in the screenshot.) Governs R1, R2, R3.

### Scope Boundaries

- Non-NixOS Linux hosts: their desktop is outside the migration.
- The day/night schedule itself (location-based or fixed times) stays at Plasma's and macOS's defaults.
- Other Appearance settings in the screenshot (Liquid Glass, theme color, highlight color, icon and widget style) stay unmanaged.
- GTK apps and browsers on Plasma follow whatever Plasma regenerates; no GTK settings are added.
- Not rewriting historical plans under `.compound-engineering/artifacts/plans/` that mention `kde-light-theme`.

### Sources

- `plasma-workspace` 6.7.5 (the flake's pin): `kcms/lookandfeel/lookandfeelsettings.kcfg` declares `[KDE] AutomaticLookAndFeel` (default false), `DefaultLightLookAndFeel` (default `org.kde.breeze.desktop`), `DefaultDarkLookAndFeel` (default `org.kde.breezedark.desktop`), `AutomaticLookAndFeelOnIdle` (default true) in `kdeglobals`. `kcms/lookandfeel/kded/lookandfeelautoswitcher.cpp` is a kded module (`X-KDE-Kded-autoload: true`) that, when the setting is on, applies the light or dark package through `KLookAndFeelManager`, which writes the scheme's color groups into the user's `kdeglobals` unconditionally (`libklookandfeel/klookandfeelmanager.cpp`, `setColors` → `applyScheme`). It skips the apply only when `LookAndFeelPackage` already equals the target.
- The built package carries `lib/qt-6/plugins/kf6/kded/lookandfeelautoswitcher.so` (checked against cache.nixos.org for the flake's `plasma-workspace` output).
- nix-darwin (the flake's pin), `modules/system/defaults/NSGlobalDomain.nix`: `AppleInterfaceStyleSwitchesAutomatically` is `nullOr bool`; `AppleInterfaceStyle` is `nullOr (enum ["Dark"])` and stays null. `modules/system/defaults-write.nix` renders it as a `defaults write -g` under `launchctl asuser` for `system.primaryUser` in the `userDefaults` activation script.

## Planning Contract

### Key Technical Decisions

- KTD1. **Use Plasma's own switcher, not a timer of our own.** `lookandfeelautoswitcher` ships in the pinned `plasma-workspace`, autoloads in kded, and is what System Settings toggles. A systemd timer calling `plasma-apply-lookandfeel` would duplicate it and would hit the cascade no-op recorded in `.compound-engineering/artifacts/solutions/integration-issues/plasma-apply-colorscheme-no-op-under-xdg-kdeglobals-cascade.md`. Inherits the session-settled auto-mode decision. Covers R2, R3.
- KTD2. **Set the switch in both layers.** `/etc/xdg/kdeglobals` covers new users (R2). The user file can hold `AutomaticLookAndFeel=false` from an earlier toggle, which overrides `/etc/xdg`, so the `kdeTheme` activation writes the three keys with `kwriteconfig6` too (R3). Name both packages explicitly rather than relying on kcfg defaults, so a stale user value is overwritten.
- KTD3. **Drop the Breeze Light identity and color writes from the `kdeTheme` activation.** With automatic mode on, the switcher owns the active theme. Writing light colors on every generation change would turn a dark evening session light until the next transition. The `lightColors` derivation goes with them. Covers R4.
- KTD7. **Delete the user-file pins that would defeat the login-time switch.** At login, `startplasma` (`startkde/startplasma.cpp`, `setupPlasmaEnvironment`) picks the day or night package from the switcher's saved schedule, writes `LookAndFeelPackage`, and writes the package's `ColorScheme` and icon theme to `~/.config/kdedefaults/kdeglobals` in Defaults mode, which does not revert the user's own entries. It then re-applies the effective scheme's colors only when `[General] ColorSchemeHash` differs from that scheme file's hash. A user-file `[General] ColorScheme` or `[Icons] Theme` therefore outranks the scheduled theme, and the kded switcher then skips its apply because `LookAndFeelPackage` already matches. Color groups that disagree with the package (left by the old forced-light writes or an earlier dark default) survive while the hash still matches. The activation deletes `[General] ColorScheme`, `[General] ColorSchemeHash`, and `[Icons] Theme` from the user file, so the next login takes them from `kdedefaults` and re-applies the scheduled scheme's colors. It leaves the color groups and `LookAndFeelPackage` alone, since login rewrites them. Covers R3, R4.
- KTD4. **Keep the Breeze Light baseline in `/etc/xdg/kdeglobals` unchanged.** It is what a session shows before kded starts and what a user who turns automatic mode off falls back to. Covers R5.
- KTD5. **Rename the check `kde-light-theme` to `kde-theme`.** It now covers the light baseline and automatic switching; the file becomes `tests/kde-theme.nix`, and the `hostClosureChecks` entry, the `checks` attribute, `docs/verification.md`, and the cascade solution's pointer follow. Covers R6.
- KTD6. **macOS: set only `AppleInterfaceStyleSwitchesAutomatically = true`.** Leave `AppleInterfaceStyle` null; macOS writes it itself while switching. Covers R1.

### Assumptions

- `AutomaticLookAndFeelOnIdle` stays at its default (true): a scheduled switch waits for 5 s of idle input, while the startup check applies immediately.
- The macOS change may need a logout to show, as nix-darwin documents for `AppleInterfaceStyle`; the PR says so and the hardware check covers it.
- macOS bootstrap outputs get the setting too, because `modules/darwin/defaults.nix` is in the shared profile and appearance carries no secret.

## Implementation Units

### U1. macOS automatic appearance

- **Goal:** Every macOS host switches appearance automatically.
- **Requirements:** R1 (KTD6).
- **Dependencies:** none.
- **Files:** `modules/darwin/defaults.nix`, `tests/darwin-config.nix`, `tests/darwin-outputs.nix`.
- **Approach:**
  1. Set `system.defaults.NSGlobalDomain.AppleInterfaceStyleSwitchesAutomatically = true` in `modules/darwin/defaults.nix`; reword its header comment, which says none are declared.
  2. In `tests/darwin-config.nix`, assert for every macOS fixture output that the option is true and `AppleInterfaceStyle` is null, beside the system-layer assertions (auto-optimise, fonts); add a line to the header comment.
  3. In `tests/darwin-outputs.nix`, read the built generation's activation script and assert it writes `AppleInterfaceStyleSwitchesAutomatically` to the global domain with a true plist value and writes no `AppleInterfaceStyle` key.
- **Patterns to follow:** the `auto-optimise-store` assertions in both darwin checks; `tests/darwin-outputs.nix` already greps `$gen/activate`.
- **Test scenarios:**
  - On the branch, `darwin-config` renders no failure line, and `darwin-outputs` passes on the Mac.
  - Mutation: remove the setting; both checks fail naming it.
  - Mutation: set it to false; both checks fail.
  - Mutation: add `AppleInterfaceStyle = "Dark"`; both checks fail.
- **Verification:** the checks pass on the branch and fail under each mutation, reverted afterwards.

### U2. Plasma automatic mode in /etc/xdg/kdeglobals

- **Goal:** Every Plasma user starts with automatic global-theme switching.
- **Requirements:** R2, R5 (KTD1, KTD4).
- **Dependencies:** none.
- **Files:** `modules/nixos/desktop/desktop.nix`.
- **Approach:** Add `AutomaticLookAndFeel=true`, `DefaultLightLookAndFeel=org.kde.breeze.desktop`, and `DefaultDarkLookAndFeel=org.kde.breezedark.desktop` to the `[KDE]` group of the rendered `/etc/xdg/kdeglobals`, beside `LookAndFeelPackage`. Leave the Breeze Light identity and color groups as they are.
- **Test scenarios:** covered by U4.
- **Verification:** the materialized `/etc/xdg/kdeglobals` carries the three keys and the unchanged light baseline.

### U3. kdeTheme activation turns on automatic mode instead of forcing light

- **Goal:** h82's own `kdeglobals` resolves to automatic mode, and rebuilds stop overriding the switcher.
- **Requirements:** R3, R4 (KTD2, KTD3, KTD7).
- **Dependencies:** none.
- **Files:** `home/h82/desktop/kde/theme.nix`.
- **Approach:**
  1. Replace the activation body with three `kwriteconfig6` writes to `[KDE]`: `AutomaticLookAndFeel` as a bool true, and the light and dark package names.
  2. Add `kwriteconfig6 --delete` calls for `[General] ColorScheme`, `[General] ColorSchemeHash`, and `[Icons] Theme` (KTD7).
  3. Remove the `ColorScheme`, `LookAndFeelPackage`, and `Icons/Theme` writes, the color-entry loop, and the `lightColors` derivation.
  4. Rewrite the module comment: the switcher and the login-time apply own the active theme; the activation writes `AutomaticLookAndFeel` true, overriding a user value that turned it off, and deletes the user pins that would outrank the scheduled theme at login. Keep the note that activation runs only when the generation changes.
- **Patterns to follow:** the `kwrite` guard (`if [ -x … ]`) the KDE modules share.
- **Test scenarios:** covered by U4.
- **Verification:** the activation script holds the three writes and none of the removed ones.

### U4. Rename and rewrite the KDE theme check

- **Goal:** `kde-theme` pins the light baseline and automatic mode in both layers.
- **Requirements:** R6 (KTD5), guarding R2-R5.
- **Dependencies:** U2, U3.
- **Files:** `tests/kde-light-theme.nix` → `tests/kde-theme.nix`, `flake.nix`, `docs/verification.md`, `.compound-engineering/artifacts/solutions/integration-issues/plasma-apply-colorscheme-no-op-under-xdg-kdeglobals-cascade.md`.
- **Approach:**
  1. Move the file and rename the check in `checks` and `hostClosureChecks` in `flake.nix`.
  2. Keep every `/etc/xdg/kdeglobals` assertion, and add the three `[KDE]` automatic keys.
  3. Reseed both activation fixtures with `AutomaticLookAndFeel=false`, stale light and dark package names, and a `[General] ColorSchemeHash`, keeping their dark (or stale) identity and color groups. Add a third fixture whose `LookAndFeelPackage` is Breeze Light while its color groups are Breeze Dark's, the mismatch KTD7 repairs.
  4. After the activation, assert the effective (user, else system) automatic keys are true and the two Breeze packages.
  5. Assert `[General] ColorScheme`, `[General] ColorSchemeHash`, and `[Icons] Theme` are absent from every fixture's user file after the activation.
  6. Assert the activation forced no light values: on the dark fixture, the user's `LookAndFeelPackage` and a `[Colors:Window]` entry keep their dark values.
  7. Keep the unrelated-key survival assertion. Drop the light-color comparison of the activation result; keep it for `/etc/xdg`.
  8. Assert the system path of every configuration ships `lookandfeelautoswitcher.so` under `lib/qt-6/plugins/kf6/kded`, so automatic mode cannot be configured without the module that reads it. Confirm the path in the built system path during implementation.
  9. Rewrite the header comment, the `kde-light-theme` paragraph in `docs/verification.md`, and the hardware checklist line there (auto switching instead of Breeze Light), and point the solution's "the check is now" line at `tests/kde-theme.nix`.
- **Patterns to follow:** the existing `ini_effective` lookup and fixture seeding in `tests/kde-light-theme.nix`; the "seed wrong values, not missing keys" rule in `.compound-engineering/artifacts/solutions/best-practices/converged-fixture-state-defeats-nix-check-mutation-testing.md`.
- **Test scenarios:**
  - On the branch, `kde-theme` builds.
  - Mutation: drop the `/etc/xdg` `AutomaticLookAndFeel` line; the check fails.
  - Mutation: drop the activation's `AutomaticLookAndFeel` write; the fixture's `false` survives and the check fails.
  - Mutation: swap the dark package name in either layer; the check fails.
  - Mutation: restore the activation's `LookAndFeelPackage` light write; the dark-fixture identity assertion fails.
  - Mutation: drop the `ColorSchemeHash` delete; the pin-absence assertion fails on every fixture.
  - Mutation: drop the Breeze Light color groups from `/etc/xdg`; the baseline assertion fails.
- **Verification:** the check passes on the branch and fails under each mutation, reverted afterwards; the `check-shards-guard` and `host-name-guard` checks still pass.

## Verification Contract

| Gate | Command | Where |
| --- | --- | --- |
| Format | `nix fmt -- --ci` | local |
| `darwin-config` and U1 mutations without a Linux builder | `nix eval --raw .#checks.x86_64-linux.darwin-config.buildCommand \| grep -F "echo '"`: no match on the branch, a match under each mutation | Mac |
| `darwin-outputs` (R1 materialized) | `nix build --no-link .#checks.aarch64-darwin.darwin-outputs` | Mac, and CI `build-darwin` |
| `kde-theme` | `nix build --no-link .#checks.x86_64-linux.kde-theme` | CI `hosts` check shard (this Mac has no Linux builder) |
| `kde-theme` mutations | each U4 mutation as a throwaway commit on a separate draft pull request, never the PR branch; read the `hosts` shard's failure line, then close the draft PR and delete its branch | CI |
| Fast checks, evaluation | `nix flake check --no-build` | local or CI |
| Host outputs | every `nixosConfigurations` and `darwinConfigurations` output builds | CI |
| Hardware, macOS | `nr switch`, log out and in, confirm System Settings > Appearance shows Auto | user, manual |
| Hardware, Plasma | rebuild, log in, confirm `qdbus6 org.kde.kded6 /kded org.kde.kded6.loadedModules` lists `lookandfeelautoswitcher` and System Settings > Global Theme shows automatic switching; log in once after dusk and confirm the session is Breeze Dark | user, manual |

Before mutation testing in a scratch copy, read `.compound-engineering/artifacts/solutions/best-practices/copied-git-worktree-writes-the-real-index.md`.

## Definition of Done

- U1-U4 are committed on one branch with `nix fmt -- --ci` clean.
- `darwin-config`, `darwin-outputs`, and `kde-theme` pass and fail under their mutations; mutations are reverted.
- CI's check shards and `build-darwin` pass.
- The PR description states that the macOS change may need a logout and that both hardware checks are pending.
- No experimental or abandoned code remains in the diff.
