---
title: LibreOffice and Okular Home Packages - Plan
type: feat
date: 2026-09-28
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# LibreOffice and Okular Home Packages - Plan

## Goal Capsule

- **Objective:** On both hosts, user `h82` can open office documents in LibreOffice and PDFs in Okular from the application launcher, and the flake fails if either stops being part of the user profile.
- **Means:** Add `libreoffice-qt` and `kdePackages.okular` to `home.packages` in `home/h82/default.nix`, guarded by one flake check per package that follows the existing `kleopatra-gui` pattern (KTD1, KTD2).
- **Authority:** This plan, then `AGENTS.md`, then existing `flake.nix` check conventions.
- **Stop conditions:** Stop if either package fails to build or evaluate on any of the four host configurations.
- **Execution profile:** Configuration plus two flake checks. No hardware installation and no `nixos-rebuild switch`.
- **Finishes the work:** `ce-work` implements and verifies with the fast Nix commands and the four host builds.

---

## Product Contract

### Summary

Install LibreOffice and Okular through Home Manager for user `h82`, and guard both with flake checks.

### Problem Frame

The user profile has no office suite. Okular is currently present only because the NixOS Plasma 6 module installs it system-wide; nothing in this repository states that the user needs a PDF viewer, so a Plasma default change or an `environment.plasma6.excludePackages` entry would remove it silently.

### Requirements

- R1. LibreOffice is in `home.packages` for `h82` on every host configuration and exposes its launcher entries (`writer`, `calc`, `impress`).
- R2. `kdePackages.okular` is in `home.packages` for `h82` on every host configuration and exposes `bin/okular`, its launcher entry, and its PDF handler entry.
- R3. A flake check fails when either package leaves the user profile or stops shipping its executable and desktop entry.

### Scope Boundaries

- Setting default MIME associations (for example PDF to Okular) is excluded; Plasma's existing defaults stay in effect.
- LibreOffice language packs, spell-check dictionaries, and Java integration are excluded.
- Removing Okular from the Plasma system package set is excluded.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Use nixpkgs `libreoffice-qt` (the fresh 26.8.0.3 release with the Qt6/KF6 VCL backend, pname `libreoffice`) so it matches the preserved Plasma desktop's widgets and file dialogs; plain `libreoffice` is the same release on the GTK backend. `libreoffice-still` is rejected because it lags the fresh release. The package is binary-cached, so builds do not compile LibreOffice.
- KTD2. Guard each package with its own `flake.nix` check modeled on `kleopatra-gui` and `telegram-desktop`: `findFirst` by `pname` in `home-manager.users.h82.home.packages`, with every store-path interpolation inside an `optionalString` guard so removal fails in the builder with a message, not at evaluation (see `.compound-engineering/artifacts/solutions/best-practices/unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md`).
- KTD3. Declare Okular in Home Manager even though Plasma already installs it system-wide, because the user asked for it as a home package and the declaration survives Plasma package-set changes.

### Assumptions

- "Home package" means `home.packages` in `home/h82/default.nix`, which both hosts import.
- Duplicate Okular in the system and user profiles is harmless; both resolve to the same store path under `home-manager.useGlobalPkgs = true`.

---

## Implementation Units

### U1. Add the packages

- **Goal:** R1, R2.
- **Files:** `home/h82/default.nix`.
- **Approach:** Insert `kdePackages.okular` and `libreoffice-qt` (KTD1) into the alphabetized `with pkgs;` list.
- **Test Scenarios:** Covered by U2.
- **Verification:** Host builds succeed.

### U2. Add flake checks

- **Goal:** R3.
- **Files:** `flake.nix` (checks beside `kleopatra-gui`).
- **Approach:** Add `libreoffice-office` and `okular-pdf` checks per KTD2. `libreoffice-office` asserts `bin/libreoffice` is executable and `share/applications/writer.desktop`, `calc.desktop`, `impress.desktop` exist. `okular-pdf` asserts `bin/okular` is executable and both `share/applications/org.kde.okular.desktop` (the launcher entry) and `share/applications/okularApplication_pdf.desktop` exist; the latter is `NoDisplay` and proves only PDF handling.
- **Test Scenarios:**
  - Package present: check builds.
  - Package removed from `home.packages`: check fails in the builder with `missing <name> in user packages`, not an evaluation error.
  - Wrong path asserted (mutation): check fails.
- **Verification:** `nix build .#checks.x86_64-linux.libreoffice-office .#checks.x86_64-linux.okular-pdf`; one-off mutation by temporarily removing each package confirms the check fails with the intended message.

---

## Verification Contract

- `nix fmt -- --ci`
- `nix flake check`
- The four host `nix build --no-link` commands from `AGENTS.md`.
- Mutation evidence for U2 per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`.

---

## Definition of Done

- Both packages are in `home/h82/default.nix`, and both checks are registered in `flake.nix`.
- All Verification Contract commands pass.
- Each check was shown to fail when its package is removed; the mutations are reverted.
- No leftover experimental edits in the diff.
