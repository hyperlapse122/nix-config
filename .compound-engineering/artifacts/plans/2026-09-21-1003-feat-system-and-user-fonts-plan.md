---
title: System and User Fonts - Plan
type: feat
date: 2026-09-21
topic: system-and-user-fonts
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
---

## Goal Capsule

- **Objective:** User `h82` has modern Korean and Latin typography, developer terminal glyphs, and colorful emojis rendered consistently across desktop applications, system fontconfig, and Ghostty terminal.
- **Means:** Declare `pretendard`, `jetbrains-mono`, `nerd-fonts.jetbrains-mono`, and `twemoji-color-font` packages in NixOS, configure fontconfig default font families, and set Ghostty's terminal font (KTD1, KTD2, KTD3).
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11. System configuration outside fonts and terminal font configuration are non-goals.
- **Open Blockers:** None.

---

## Product Contract

*Product Contract preservation: Product Contract unchanged.*

### Summary

Declare `pretendard`, `jetbrains-mono`, `nerd-fonts.jetbrains-mono`, and `twemoji-color-font` as system packages in NixOS. Set Pretendard as the default system UI and sans-serif font, JetBrainsMono Nerd Font as the default monospace font across fontconfig and Ghostty, and Twemoji Color Font as the default emoji font.

### Problem Frame

The ThinkPad NixOS system currently declares zero custom font packages or fontconfig defaults, relying on unmanaged upstream NixOS defaults. This leaves user interfaces without modern multilingual typography for Korean text, lacks developer Nerd Font glyphs and powerline symbols in coding terminals, and provides inconsistent emoji rendering across desktop applications.

### Key Decisions

- **Set Pretendard as default sans-serif and JetBrainsMono Nerd Font as default monospace across system fontconfig, Plasma, and Ghostty.** (session-settled: user-directed — chosen over fontconfig-only or standard JetBrains Mono: provides unified typography with full developer glyph support across desktop and terminal.) Governs R1, R2, R3, R4, R5.
- **Prioritize Twemoji Color Font as default emoji font.** (session-settled: user-directed — chosen over default Noto Color Emoji: provides consistent Twitter Unicode emoji rendering across applications.) Governs R1, R4.
- **Retain Noto font families as secondary fallbacks in fontconfig.** Governs R2, R3, R4.
- **Manage system fonts and fontconfig in NixOS system modules while configuring Ghostty font in Home Manager.** Governs R1, R2, R3, R4, R5.

### Requirements

**Font Packages**

- R1. The system configuration includes `pkgs.pretendard`, `pkgs.jetbrains-mono`, `pkgs.nerd-fonts.jetbrains-mono`, and `pkgs.twemoji-color-font` in `fonts.packages`.

**Fontconfig Defaults**

- R2. System fontconfig defines `defaultFonts.sansSerif` with `Pretendard` as primary.
- R3. System fontconfig defines `defaultFonts.monospace` with `JetBrainsMono Nerd Font` as primary and `Noto Sans Mono` as fallback.
- R4. System fontconfig defines `defaultFonts.emoji` with `Twitter Color Emoji` as primary and `Noto Color Emoji` as fallback.

**Terminal Configuration**

- R5. Ghostty terminal configuration in Home Manager explicitly pins `font-family` to `JetBrainsMono Nerd Font`.

### Acceptance Examples

- AE1. Font availability
  - **Trigger:** Rebuilding system with `nixos-rebuild build`.
  - **Covers R1.**
  - **Given:** The flake configuration is evaluated.
  - **When:** `fonts.packages` is inspected.
  - **Then:** All four font packages are present in the system font path.
- AE2. Monospace font resolution
  - **Trigger:** Querying fontconfig for monospace.
  - **Covers R3, R5.**
  - **Given:** A terminal or developer tool queries fontconfig for `monospace`.
  - **When:** `fc-match monospace` is executed.
  - **Then:** The resolved font family is `JetBrainsMono Nerd Font`.
- AE3. Sans-serif font resolution
  - **Trigger:** Querying fontconfig for sans-serif.
  - **Covers R2.**
  - **Given:** A desktop application or browser queries fontconfig for `sans-serif`.
  - **When:** `fc-match sans-serif` is executed.
  - **Then:** The resolved font family is `Pretendard`.
- AE4. Emoji font resolution
  - **Trigger:** Querying fontconfig for emoji.
  - **Covers R4.**
  - **Given:** An application renders emoji.
  - **When:** `fc-match emoji` is executed.
  - **Then:** The resolved font family is `Twitter Color Emoji`.

### Scope Boundaries

- Plasma widget themes, color schemes, or window decoration styles are not modified.
- Additional non-default font families (e.g. Fira Code, Cascadia Code) are deferred.
- Ghostty terminal color themes or keybindings are outside this scope.

### Sources / Research

- Pretendard package derivation: `pkgs/data/fonts/pretendard/default.nix` in `nixpkgs` (`pkgs.pretendard`)
- JetBrains Mono package derivation: `pkgs/by-name/je/jetbrains-mono/package.nix` in `nixpkgs` (`pkgs.jetbrains-mono`)
- JetBrains Mono Nerd Font derivation: `pkgs/data/fonts/nerd-fonts/default.nix` in `nixpkgs` (`pkgs.nerd-fonts.jetbrains-mono`)
- Twemoji Color Font package derivation: `pkgs/by-name/tw/twemoji-color-font/package.nix` in `nixpkgs` (`pkgs.twemoji-color-font`)
- Existing desktop module: `modules/nixos/desktop.nix`
- Existing terminal module: `home/h82/terminal.nix`

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Create a dedicated `modules/nixos/fonts.nix` module.** Follows repository guideline "Keep each module focused on one concern" by isolating font packages and fontconfig configuration into a dedicated module rather than cluttering `desktop.nix` or `base.nix`. Imported via `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`. Governs R1, R2, R3, R4.
- KTD2. **Configure fontconfig default font lists with fallbacks.** Primary entries are set to `Pretendard`, `JetBrainsMono Nerd Font`, and `Twitter Color Emoji`, with `Noto Sans`, `Noto Sans Mono`, and `Noto Color Emoji` appended as secondary fallbacks for complete glyph and multilingual symbol coverage. Governs R2, R3, R4.
- KTD3. **Use Home Manager's `programs.ghostty` module for terminal font setting.** Replace raw package addition (`home.packages = [ pkgs.ghostty ];`) with `programs.ghostty = { enable = true; settings = { font-family = "JetBrainsMono Nerd Font"; }; };`. Governs R5.

### Assumptions

- The `pkgs.nerd-fonts.jetbrains-mono` package provides the font family name `"JetBrainsMono Nerd Font"`.
- The `pkgs.twemoji-color-font` package provides the font family name `"Twitter Color Emoji"`.
- `programs.ghostty` in Home Manager natively accepts key-value attributes in `programs.ghostty.settings`.

---

## Implementation Units

### U1. System Font Packages and Fontconfig Configuration

- **Goal:** Declare `pretendard`, `jetbrains-mono`, `nerd-fonts.jetbrains-mono`, and `twemoji-color-font` in a dedicated NixOS module with fontconfig default family preferences.
- **Files:**
  - `modules/nixos/fonts.nix` (create)
  - `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix` (modify)
- **Requirements:** R1, R2, R3, R4
- **Acceptance:** AE1, AE2, AE3, AE4
- **Approach:**
  - Create `modules/nixos/fonts.nix`:
    ```nix
    { pkgs, ... }:
    {
      fonts = {
        enableDefaultPackages = true;
        packages = with pkgs; [
          pretendard
          jetbrains-mono
          nerd-fonts.jetbrains-mono
          twemoji-color-font
        ];
        fontconfig = {
          enable = true;
          defaultFonts = {
            sansSerif = [ "Pretendard" "Noto Sans" ];
            monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono" ];
            emoji = [ "Twitter Color Emoji" "Noto Color Emoji" ];
          };
        };
      };
    }
    ```
  - In `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, add `../../modules/nixos/fonts.nix` to `imports`.
- **Test Scenarios:**
  - Test 1: Evaluate `config.fonts.packages` on `ThinkPad-X1-Carbon-Gen-11` and ensure all 4 packages are present.
  - Test 2: Evaluate `config.fonts.fontconfig.defaultFonts` on `ThinkPad-X1-Carbon-Gen-11` and ensure `Pretendard`, `JetBrainsMono Nerd Font`, and `Twitter Color Emoji` are heads of their respective lists.
  - Test 3: Evaluate on `ThinkPad-X1-Carbon-Gen-11-bootstrap` to ensure bootstrap builds also succeed with the new fonts module.
- **Verification:**
  `nix eval --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.fonts.fontconfig.defaultFonts'`

### U2. User Ghostty Terminal Font Configuration

- **Goal:** Declaratively set `JetBrainsMono Nerd Font` as the default font family for Ghostty in Home Manager.
- **Files:**
  - `home/h82/terminal.nix` (modify)
- **Requirements:** R5
- **Acceptance:** AE2
- **Approach:**
  - In `home/h82/terminal.nix`, migrate from `home.packages = [ pkgs.ghostty ];` to:
    ```nix
    { pkgs, ... }:
    {
      programs.ghostty = {
        enable = true;
        settings = {
          font-family = "JetBrainsMono Nerd Font";
        };
      };
    }
    ```
- **Test Scenarios:**
  - Test 1: Evaluate `config.home-manager.users.h82.programs.ghostty.enable` to verify it is `true`.
  - Test 2: Evaluate `config.home-manager.users.h82.programs.ghostty.settings.font-family` to verify it equals `"JetBrainsMono Nerd Font"`.
- **Verification:**
  `nix eval --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.home-manager.users.h82.programs.ghostty.settings.font-family'`

---

## Verification Contract

Run the repository's verification checks and builds:

```sh
# 1. Format check
nix fmt -- --ci

# 2. Declared flake checks
nix flake check

# 3. Full toplevel system builds for both production and bootstrap targets
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel
```

---

## Definition of Done

- All requirements (R1, R2, R3, R4, R5) are implemented and verified.
- Nix code layout conforms to repository conventions and passes `nix fmt -- --ci`.
- All flake checks pass (`nix flake check`).
- Both `ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap` toplevels build cleanly without errors or warnings.
- No temporary files, debug code, or uncommitted cruft remain.
