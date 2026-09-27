---
title: KDE Breeze Dark Theme - Plan
type: feat
date: 2026-09-27
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# KDE Breeze Dark Theme - Plan

## Goal Capsule

- **Objective:** On both hosts, a Plasma session for `h82` (and for any new user) opens in Breeze Dark: dark window colors, dark Plasma panels, and dark icons, without the user picking it in System Settings.
- **Means:** declare Breeze Dark in the system `/etc/xdg` KDE defaults and reassert it in the `h82` Home Manager KDE activation, following the existing `kwriteconfig6` pattern (KTD1, KTD2).
- **Authority:** this plan's Requirements, then KTDs, then units. `AGENTS.md` build and check rules apply throughout.
- **Stop conditions:** stop if Breeze Dark assets are not in the built system path, or if applying the color scheme in activation needs a running graphical session and cannot be made to degrade to a no-op.
- **Execution profile:** Nix configuration plus one evaluation-time check; no hardware installation, no `nixos-rebuild switch`.

---

## Product Contract

### Summary

Make Breeze Dark the Plasma appearance on ThinkPad-X1-Carbon-Gen-11 and MS-7D91 by setting the Breeze Dark global theme, color scheme, and icon theme declaratively at both the system-default and user level.

### Problem Frame

The flake leaves Plasma on its stock Breeze (light) appearance. The user wants dark mode. Today that would be a manual System Settings click, which a fresh install or a new machine loses; the repo already declares other Plasma preferences (task manager, KRunner, power, locale) so the appearance belongs beside them.

### Requirements

**Appearance**

- R1. The Plasma look-and-feel package is `org.kde.breezedark.desktop` and the color scheme is `BreezeDark` for `h82` on both production hosts.
- R2. The icon theme is `breeze-dark`, matching what the Breeze Dark look-and-feel package itself sets.
- R3. Qt/KDE applications render dark colors on first login, which requires the Breeze Dark `[Colors:*]` groups to be present in effective `kdeglobals`, not only the `ColorScheme` name.

**Scope of application**

- R4. The same defaults apply system-wide through `/etc/xdg` so a user without a `~/.config/kdeglobals` also gets Breeze Dark.
- R5. Both bootstrap configurations still build; the change must not depend on secrets or production-only modules.

### Scope Boundaries

- SDDM greeter theme is out of scope; it keeps its current theme.
- GTK application theming, wallpaper, window decoration, cursor, and splash are left at their Breeze defaults (the Breeze Dark look-and-feel shares them with Breeze).
- No automatic day/night switching.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **System default via `/etc/xdg/kdeglobals`, with the color groups copied from the packaged `BreezeDark.colors`.** `modules/nixos/desktop/desktop.nix` already owns `environment.etc."xdg/kdeglobals"`; extend that text with `[KDE] LookAndFeelPackage`, `[General] ColorScheme`, `[Icons] Theme`, and append the `[Colors:*]`, `[WM]`, and `[ColorEffects:*]` groups read at build time from `${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors`. KF6 `KColorScheme` reads colors from `kdeglobals` groups and falls back to built-in light values when they are absent, so the name alone does not satisfy R3. Reading the file from the package, rather than pasting values, keeps the colors in step with the pinned Breeze version. Omit the colors file's own `[General]` metadata (`Name`) if it would clash with the existing `[General]` group, or merge it; decide at implementation after checking KConfig duplicate-group behavior.
- KTD2. **User level via a new `kdeTheme` Home Manager activation in `home/h82/desktop/kde/theme.nix`.** `~/.config/kdeglobals` already exists on the running hosts with light `[Colors:*]` groups that override `/etc/xdg`, so R1 and R3 need a user-level write. Use `kwriteconfig6` (same guard and style as `apps.nix`) for `General/ColorScheme`, `KDE/LookAndFeelPackage`, `Icons/Theme`, and every `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` entry of the packaged `BreezeDark.colors`, listed at build time. Do not use `plasma-apply-colorscheme`: it reads the cascaded `ColorScheme=BreezeDark` from `/etc/xdg` as already applied and writes nothing, and it aborts without a display. Do not call `plasma-apply-lookandfeel`: it can reset panel layout and needs a graphical session.
- KTD3. **Plasma style stays `default`.** The Breeze Dark look-and-feel defaults set `plasmarc [Theme] name=default`, and the default Plasma style follows the color scheme, so no separate `breeze-dark` desktop theme is forced.
- KTD4. **Activation reasserts only when the Home Manager generation changes.** Per `.compound-engineering/artifacts/solutions/best-practices/home-manager-activation-does-not-run-on-every-rebuild.md`, comments and docs must not claim the theme is reasserted on every rebuild.

---

## Implementation Units

### U1. System-wide Breeze Dark defaults

- **Goal:** `/etc/xdg/kdeglobals` carries the Breeze Dark look-and-feel, color scheme, icon theme, and color groups on all four configurations.
- **Requirements:** R1, R2, R3, R4, R5
- **Dependencies:** none
- **Files:** `modules/nixos/desktop/desktop.nix`, `tests/kde-dark-theme.nix`, `flake.nix`
- **Approach:** extend the existing `environment.etc."xdg/kdeglobals".text` per KTD1; keep `TerminalApplication` and `Locale` entries intact.
- **Patterns to follow:** existing `environment.etc."xdg/*"` blocks in `modules/nixos/desktop/desktop.nix`.
- **Test scenarios:**
  - For each of the four configurations, the materialized `/etc/xdg/kdeglobals` file (read through the built `etc` tree or the entry's `source`, not the `.text` option) contains `LookAndFeelPackage=org.kde.breezedark.desktop`, `ColorScheme=BreezeDark`, and `Theme=breeze-dark`.
  - The same file contains a `[Colors:Window]` group whose `BackgroundNormal` equals the value in the packaged `BreezeDark.colors`, and differs from the one in `BreezeLight.colors` (so a light scheme cannot pass).
  - Existing `TerminalApplication=ghostty` and `Language=ko:en_US` lines are still present.
- **Verification:** `nix build .#checks.x86_64-linux.kde-dark-theme` passes; mutating the color scheme name or dropping the color groups turns it red.

### U2. User-level Breeze Dark activation

- **Goal:** `h82`'s own `kdeglobals` is switched to Breeze Dark on the next Home Manager generation.
- **Requirements:** R1, R2, R3
- **Dependencies:** U1 (shares the test file)
- **Files:** `home/h82/desktop/kde/theme.nix`, `home/h82/desktop/kde/default.nix`, `tests/kde-dark-theme.nix`
- **Approach:** new `home.activation.kdeTheme` after `writeBoundary` per KTD2 and KTD4; import it from `home/h82/desktop/kde/default.nix`.
- **Patterns to follow:** `home/h82/desktop/kde/apps.nix` (guarded `kwriteconfig6`), `home/h82/desktop/kde/input.nix` (tolerated runtime command).
- **Test scenarios:**
  - On both production hosts, running the `kdeTheme` activation against a fixture home whose `kdeglobals` holds Breeze Light values, with the built `/etc/xdg` in `XDG_CONFIG_DIRS`, leaves the resolved `ColorScheme`, `LookAndFeelPackage`, icon theme, `[Colors:Window]`, and nested `[Colors:Header][Inactive]` values at Breeze Dark.
  - An unrelated user key survives the activation.
- **Verification:** the check passes; the activation data is non-empty on both hosts.

### U3. Documentation

- **Goal:** the check and the hardware confirmation are recorded.
- **Requirements:** R1, R3
- **Dependencies:** U1, U2
- **Files:** `docs/verification.md`
- **Approach:** describe `kde-dark-theme` in the checks paragraph and add a hardware checklist item: after a rebuild that produces a new Home Manager generation, log in and confirm Plasma panels, Dolphin, and System Settings are dark.
- **Test expectation:** none -- documentation only.

---

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Checks | `nix flake check` (includes the new `kde-dark-theme`) |
| Host builds | the four `nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel` commands in `AGENTS.md` |

Mutation-test the new check per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: change `BreezeDark` to `BreezeLight` and remove the color groups, and confirm each mutation fails the build.

## Definition of Done

- U1–U3 landed; all gates above pass.
- The check reads materialized output and fails under the listed mutations.
- No abandoned-attempt code remains in the diff.
- Hardware confirmation is left as a checklist item, reported separately from check evidence.
