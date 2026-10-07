---
title: KDE Breeze Light Default - Plan
type: feat
date: 2026-10-07
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# KDE Breeze Light Default - Plan

## Goal Capsule

- **Objective:** Plasma sessions on every NixOS host render in Breeze Light by default, both for new users and for h82, whose existing `~/.config/kdeglobals` currently holds Breeze Dark values.
- **Means:** Flip the existing two-layer theme mechanism (system `/etc/xdg/kdeglobals` plus the `kdeTheme` Home Manager activation) from Breeze Dark to Breeze Light, keeping its structure (KTD1, KTD2).
- **Authority:** Product Contract requirements win on behavior; KTDs win on mechanism.
- **Stop conditions:** Stop if the packaged `BreezeLight.colors` lacks a color group or key that `BreezeDark.colors` carries, since the user-layer overwrite would then leave dark entries behind.
- **Execution profile:** Mostly configuration; the proof is the rewritten `kde-light-theme` check, mutation-tested, plus the host builds.
- **Finish and ship:** `ce-work` implements and verifies locally; the calling pipeline ships.

## Product Contract

### Summary

Make Breeze Light the default Plasma look-and-feel, color scheme, and icon theme, at the system layer and in h82's own `kdeglobals`, and keep the regression check guarding the new default.

### Problem Frame

The desktop was switched to Breeze Dark in an earlier change, which made dark the default in `/etc/xdg/kdeglobals` and converted h82's user file through activation. The user now wants light as the main theme. Because h82's user file already carries Breeze Dark color groups that override the system defaults, changing only the system layer would leave h82 dark, the same cascade trap documented in `.compound-engineering/artifacts/solutions/integration-issues/plasma-apply-colorscheme-no-op-under-xdg-kdeglobals-cascade.md`.

### Requirements

**System default**

- R1. `/etc/xdg/kdeglobals` names `ColorScheme=BreezeLight`, `LookAndFeelPackage=org.kde.breeze.desktop`, and icon theme `breeze`, and carries the Breeze Light `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` groups, on production and bootstrap configurations alike.
- R2. The existing `TerminalApplication=ghostty` and `[Locale] Language=ko:en_US` entries survive.

**User conversion**

- R3. After the next Home Manager generation change, h82's effective kdeglobals values (user file, else system) are the Breeze Light ones, even when the user file starts out holding Breeze Dark values.
- R4. Unrelated user keys in `kdeglobals` survive the conversion.

**Guard**

- R5. A repository check fails when any of R1-R4 regresses, including a dark scheme sneaking back in.

### Scope Boundaries

- Fcitx5 stays as is: `UseDarkTheme=True` makes it follow the system color scheme, so it turns light with Plasma.
- VSCodium's `Solarized Dark` editor theme, Ghostty, and browsers are not KDE theme settings and stay unchanged.
- No light/dark toggle or per-host theme option; the request is a single default, and nothing needs to vary by host.
- Non-NixOS hosts get no desktop, so nothing changes there.

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep the two-layer mechanism and swap the scheme.** The system layer appends groups from `BreezeLight.colors` instead of `BreezeDark.colors`, and the user activation writes the light identity keys and every light color entry with `kwriteconfig6`. This reuses the design the solution doc proved; `plasma-apply-colorscheme` would no-op under the cascade for the same reason it did for dark.
- KTD2. **The activation stays.** Without it, h82's user file keeps the dark color groups written by the previous activation, and they override the light system defaults (R3). In the pinned breeze 6.7.5, `BreezeDark.colors` and `BreezeLight.colors` share the same color group and key set (only `[General] Name[...]` translations differ, which are not copied), so overwriting every light entry fully replaces the dark ones. This was verified while planning; the Goal Capsule stop condition covers a later breeze bump that breaks it.
- KTD3. **Rename the check to `kde-light-theme`.** The name states what it guards; update the `flake.nix` registration, the `hostClosureChecks` entry, and `docs/verification.md`. Seed its user fixture with Breeze Dark values (identity keys plus every dark `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` group the activation copies), the inverse of today's fixture, so a dropped write cannot pass by cascading from the light system defaults. Assert every copied entry, not a sample: a check that compares only two color keys passes when `[WM]` or any single group is lost.

## Implementation Units

### U1. Switch system and user layers to Breeze Light

- **Goal:** Make Breeze Light the default at both layers.
- **Requirements:** R1, R2, R3, R4; KTD1, KTD2.
- **Dependencies:** none.
- **Files:** `modules/nixos/desktop/desktop.nix`, `home/h82/desktop/kde/theme.nix`.
- **Approach:**
  1. In `desktop.nix`, change the rendered `[General] ColorScheme`, `[Icons] Theme`, and `[KDE] LookAndFeelPackage` to the light values and read groups from `BreezeLight.colors`; adjust the comment that says `ColorScheme=BreezeDark` alone leaves Qt apps light (with a light scheme the reason for appending groups is that a stale user or built-in fallback can disagree; keep the comment accurate).
  2. In `theme.nix`, rename the generated entry list and derivation to light, write the light identity keys, and update the comment to say the user file carries dark groups from the previous default.
- **Patterns to follow:** the existing dark implementation in the same files.
- **Test scenarios:** covered by U2.
- **Verification:** both files evaluate and every host's toplevel builds.

### U2. Rewrite the regression check for Breeze Light

- **Goal:** Guard R1-R4 with the inverted fixture (R5).
- **Requirements:** R5; KTD3.
- **Dependencies:** U1.
- **Files:** `tests/kde-dark-theme.nix` renamed to `tests/kde-light-theme.nix`, `flake.nix`, `docs/verification.md`, `.compound-engineering/artifacts/solutions/integration-issues/plasma-apply-colorscheme-no-op-under-xdg-kdeglobals-cascade.md` (regression-check pointer only).
- **Approach:**
  1. Flip every expected identity value to light. For both the built `/etc/xdg/kdeglobals` and the effective values after activation, loop over every `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` entry in `BreezeLight.colors` (nested groups included) and require it to match. Keep the guard that the light Window background differs from the dark one.
  2. Seed the fixture user file with `ColorScheme=BreezeDark`, icon theme `breeze-dark`, `LookAndFeelPackage=org.kde.breezedark.desktop`, and every dark `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` group, using the same group filter the activation uses.
  3. Rename the check in `flake.nix` (registration and `hostClosureChecks`), update its `docs/verification.md` description and the hardware checklist line to Breeze Light, and point the solution doc's regression-check line at the new file name.
- **Test scenarios:**
  - Built `/etc/xdg/kdeglobals` on every configuration carries the light identity keys, the light Window background, the terminal entry, and the locale.
  - Built `/etc/xdg/kdeglobals` carries every light `[Colors:*]`, `[ColorEffects:*]`, and `[WM]` entry.
  - Running the `kdeTheme` activation against a dark-seeded user file resolves ColorScheme, LookAndFeelPackage, icon theme, and every copied color entry (including nested Header/Inactive and `[WM]`) to the light values.
  - An unrelated user key (`BrowserApplication`) survives activation.
- **Execution note:** Mutation-test the check per the solution doc: dropping each identity write, emptying the color list, joining nested groups, dropping `[WM]` from the activation's group filter, dropping `[WM]` from the `desktop.nix` group filter, and reverting `desktop.nix` to `BreezeDark.colors` must each make it fail.
- **Verification:** `kde-light-theme` passes on the change and fails under each mutation.

## Verification Contract

| Gate | Command |
| --- | --- |
| Format | `nix fmt -- --ci` |
| Flake checks | `nix flake check` |
| Theme check | `nix build --no-link .#checks.x86_64-linux.kde-light-theme` |
| Host shard | `nix build --no-link .#checkShards.hosts` |
| Host builds | every `nixosConfigurations.<host>.config.system.build.toplevel`, production and bootstrap |

VM checks do not cover this change; build them only if the pipeline's shipping gate requires the full AGENTS.md list.

## Definition of Done

- U1 and U2 land; no `BreezeDark`, `breezedark`, or `breeze-dark` remains in `modules/`, `home/`, or `tests/` except the dark fixture seed and the light-vs-dark distinctness guard.
- The renamed check passes and every listed mutation fails it.
- No leftover experimental code in the diff.
