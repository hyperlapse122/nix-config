---
title: Add Telegram and Discord User Packages - Plan
type: feat
date: 2026-09-22
topic: telegram-and-discord
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** User `h82` has Telegram Desktop and Discord desktop messaging applications installed and accessible from the Plasma desktop environment on ThinkPad X1 Carbon Gen 11.
- **Means:** Add `telegram-desktop` and `discord` to `home.packages` in `home/h82/default.nix`, and register regression checks `telegram-desktop` and `discord` in `flake.nix` with derivation guards that protect against removal and verify binaries and `.desktop` files.
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11. System packages in `modules/nixos/base.nix` and desktop customization outside package provisioning are non-goals.
- **Open Blockers:** None.

---

## Product Contract

### Summary

Install Telegram Desktop and Discord as Home Manager user packages for user `h82`, providing graphical desktop messaging clients integrated into Plasma desktop menus and KRunner, backed by regression checks in `flake.nix`.

### Problem Frame

The ThinkPad X1 Carbon Gen 11 environment currently provides productivity tools, terminals, and browsers (`google-chrome`), but lacks primary messaging applications (Telegram and Discord). Routine communication requires opening web interfaces in Chrome. Installing native desktop packages (`telegram-desktop` and `discord`) provides system tray integration, native Wayland support, and desktop notifications within the existing Plasma 6 desktop session.

### Key Decisions

- Install `telegram-desktop` and `discord` as Home Manager user packages in `home/h82/default.nix` rather than system-wide packages in `modules/nixos/base.nix` (session-settled: user-directed — chosen over `environment.systemPackages`: keeps user applications scoped to user `h82`, matching `google-chrome`, `kdePackages.kleopatra`, and other personal desktop tools). Governs R1, R2.
- Protect package declarations with dedicated flake regression checks in `flake.nix` using `findFirst` and `lib.optionalString` guards (session-settled: user-directed — chosen over boolean-only assertions or unguarded store-path interpolations: ensures mutation testing fails inside the builder with explicit diagnostic messages rather than crashing the Nix evaluator). Governs R3, R4.

### Requirements

**Availability**
- R1. User `h82` has Telegram Desktop installed through `home.packages`, providing the `Telegram` executable on PATH and the `org.telegram.desktop.desktop` desktop launcher.
- R2. User `h82` has Discord installed through `home.packages`, providing the `discord` executable on PATH and the `discord.desktop` desktop launcher.

**Regression Guard**
- R3. A flake check `telegram-desktop` fails inside the builder if `telegram-desktop` is missing from user packages or if it lacks its executable or desktop file.
- R4. A flake check `discord` fails inside the builder if `discord` is missing from user packages or if it lacks its executable or desktop file.

### Acceptance Examples

- AE1. Telegram Desktop availability
  - **Covers R1, R3.**
  - **Given:** A built home-manager environment for user `h82`.
  - **When:** `Telegram` is located in the user profile.
  - **Then:** Executable `bin/Telegram` and desktop file `share/applications/org.telegram.desktop.desktop` are present and executable/readable.

- AE2. Discord availability
  - **Covers R2, R4.**
  - **Given:** A built home-manager environment for user `h82`.
  - **When:** `discord` is located in the user profile.
  - **Then:** Executable `bin/discord` and desktop file `share/applications/discord.desktop` are present and executable/readable.

- AE3. Regression check builder failures on mutation
  - **Covers R3, R4.**
  - **Given:** A mutated configuration where `telegram-desktop` or `discord` is removed from `home/h82/default.nix`.
  - **When:** `nix build --no-link .#checks.x86_64-linux.telegram-desktop` or `.#checks.x86_64-linux.discord` is run.
  - **Then:** The check fails inside the builder with an explicit missing package message, not an evaluation null coercion error.

### Scope Boundaries

- No changes to system packages in `modules/nixos/base.nix`.
- No modifications to Plasma autostart (`~/.config/autostart`) or custom hotkeys.
- Stock upstream packages from `nixpkgs` (unwrapped/standard `discord` and `telegram-desktop`). No third-party Discord clients or unfree workarounds needed since `allowUnfree = true` is already configured in `flake.nix` and `modules/nixos/base.nix`.

### Sources / Research

- `home/h82/default.nix`: existing Home Manager user package set.
- `flake.nix`: existing checks, specifically `kleopatra-gui` pattern.
- `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`: derivation guard pattern with `absent` and `present` blocks.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: mutation-testing discipline.

---

## Planning Contract

### Key Technical Decisions

- KTD1: Declare `discord` and `telegram-desktop` in alphabetical order in `home.packages` in `home/h82/default.nix`.
- KTD2: Declare two separate flake checks in `flake.nix`: `telegram-desktop` and `discord`. Both will use `lib.lists.findFirst (p: (p.pname or "") == "<name>") null userPackages`, with `optionalString` guards for `absent` and `present` states.
- KTD3: In `telegram-desktop` check, assert `bin/Telegram` is executable and `share/applications/org.telegram.desktop.desktop` is a regular file.
- KTD4: In `discord` check, assert `bin/discord` is executable and `share/applications/discord.desktop` is a regular file.

### Sequencing and Dependencies

- U1: Update `home/h82/default.nix`.
- U2: Update `flake.nix` to register checks `telegram-desktop` and `discord`.
- U3: Verify checks, format, mutation test, and system build.

---

## Implementation Units

### U1. Declare Telegram and Discord in user packages

- **Goal:** Add `discord` and `telegram-desktop` to `home.packages` for user `h82`.
- **Files:** `home/h82/default.nix`
- **Verification:** Evaluates cleanly under nixpkgs.

### U2. Register regression checks in flake.nix

- **Goal:** Add `telegram-desktop` and `discord` checks to `checks.${system}` in `flake.nix`.
- **Files:** `flake.nix`
- **Verification:** `nix build --no-link .#checks.x86_64-linux.telegram-desktop` and `.#checks.x86_64-linux.discord` succeed.

### U3. Verification, mutation testing, and builds

- **Goal:** Perform full local verification across checks, format, mutation tests, and system builds.
- **Files:** none (verification)
- **Verification:**
  - `nix fmt -- --ci`
  - `nix flake check`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`
  - Mutation testing: removing either package produces a builder failure in its respective check.

---

## Verification Contract

- Check `telegram-desktop`: `nix build --no-link .#checks.x86_64-linux.telegram-desktop`
- Check `discord`: `nix build --no-link .#checks.x86_64-linux.discord`
- Repository flake checks: `nix flake check`
- Tree formatting: `nix fmt -- --ci`
- System toplevel builds:
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`

---

## Definition of Done

- `telegram-desktop` and `discord` are declared in `home/h82/default.nix`.
- `telegram-desktop` and `discord` regression checks are declared in `flake.nix`.
- Both checks pass on the clean branch.
- Mutation testing confirms both checks fail inside the builder when packages are removed.
- `nix fmt -- --ci` passes.
- `nix flake check` passes.
- Both system builds succeed.
