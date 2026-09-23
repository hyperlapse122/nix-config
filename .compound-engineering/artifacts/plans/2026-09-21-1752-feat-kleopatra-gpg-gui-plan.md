---
title: Kleopatra GPG Graphical UI - Plan
type: feat
date: 2026-09-21
topic: kleopatra-gpg-gui
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** User `h82` can inspect and manage OpenPGP certificates on the ThinkPad X1 Carbon Gen 11 through a graphical application launched from the Plasma desktop, instead of only through `gpg` on the command line.
- **Means:** Declare `kdePackages.kleopatra` in the Home Manager package set for user `h82` (KTD1).
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11. System-level package changes and Plasma desktop customization are non-goals.
- **Open Blockers:** None.

---

## Product Contract

### Summary

Add Kleopatra, the KDE graphical front end for GnuPG, to the Home Manager package set for user `h82`, so OpenPGP certificate management has a graphical path alongside the existing declarative `gpg` and `gpg-agent` configuration.

### Problem Frame

`home/h82/gpg.nix` already configures `programs.gpg` with a hardened settings block, imports the signing public key at ultimate trust, and runs `services.gpg-agent` behind the repository's `pinentry-card` wrapper. Every interaction with that keyring is command-line only. Routine tasks — confirming which certificates are present, reading expiry dates, checking the OpenPGP smart card's status, inspecting trust — currently require remembering `gpg` invocations and reading its terse output. The desktop is Plasma, so a KDE-native certificate manager fits the environment the user already runs.

### Key Decisions

- Install Kleopatra as a Home Manager user package rather than a system package (session-settled: user-directed — chosen over `environment.systemPackages` in `modules/nixos/`: keeps user-facing applications scoped to user `h82`, matching how every other user application in this repository is declared). Governs R1, R2.
- GnuPG configuration is managed only through Home Manager; Kleopatra manages certificates and never changes GnuPG settings (session-settled: user-directed — chosen over documenting a workaround for Kleopatra's own GnuPG settings page: configuration stays declarative in one place, so the read-only config files are the intended design rather than a limitation to work around). Governs R3, R4.

### Requirements

**Availability**

- R1. User `h82` has Kleopatra installed through `home.packages`, providing the `kleopatra` executable on PATH.
- R2. Kleopatra appears as a launchable application in the Plasma desktop's application menu and KRunner for user `h82`.

**Interoperability with existing GnuPG configuration**

- R3. Kleopatra reads the same `~/.gnupg` keyring that the existing `programs.gpg` configuration manages, so the signing certificate imported in `home/h82/gpg.nix` is visible in its certificate list.
- R4. Passphrase and card-PIN prompts raised through Kleopatra are served by the `gpg-agent` pinentry already configured in `home/h82/gpg.nix`, with no second pinentry declaration.

**Regression guard**

- R5. A flake check fails if Kleopatra is removed from the user package set.

### Acceptance Examples

- AE1. Command availability
  - **Covers R1.**
  - **Given:** An interactive shell session for user `h82` after a rebuild.
  - **When:** `command -v kleopatra` is executed.
  - **Then:** A path inside the user profile is printed.

- AE2. Desktop launch
  - **Covers R2.**
  - **Given:** A Plasma session for user `h82`.
  - **When:** The user searches "Kleopatra" in KRunner.
  - **Then:** The Kleopatra entry appears and launching it opens the certificate manager window.

- AE3. Existing keyring visible
  - **Covers R3.**
  - **Given:** Kleopatra is open and `home/h82/gpg.nix` has imported `keys/signing.asc`.
  - **When:** The user views the certificate list.
  - **Then:** The signing certificate is listed with its ultimate trust level.

- AE4. Pinentry path unchanged
  - **Covers R4.**
  - **Given:** An OpenPGP smart card is inserted and Kleopatra triggers an operation requiring the card PIN.
  - **When:** `gpg-agent` requests the PIN.
  - **Then:** No Kleopatra-specific pinentry appears. When the card PIN is cached in the keyring, the `pinentry-card` wrapper answers `gpg-agent` directly and no dialog is shown; only when no cached PIN exists does the wrapper's `pinentry-qt` dialog appear.

### Scope Boundaries

- No change to `home/h82/gpg.nix`. The existing `programs.gpg` settings, key import, and `services.gpg-agent` pinentry configuration are already correct for graphical use and are left untouched.
- No system-level package changes in `modules/nixos/`.
- No Plasma configuration change in `home/h82/kde/`. Kleopatra's desktop entry is discovered through the standard user profile XDG data path; no `kwriteconfig6` activation entry is needed.
- Kleopatra's own persisted UI preferences are left at their defaults and are not declared.
- Changing GnuPG configuration through Kleopatra is out of scope. `~/.gnupg/gpg.conf` and `~/.gnupg/scdaemon.conf` stay read-only declarative symlinks, and settings changes go through `home/h82/gpg.nix` and a rebuild. This is the intended design, not a limitation to document a workaround for (KTD in Key Decisions).

### Deferred to Follow-Up Work

- Declaring Kleopatra's own configuration (`~/.config/kleopatrarc`) if defaults prove unsuitable in daily use.

### Sources / Research

- `home/h82/default.nix`: Home Manager package list for user `h82`.
- `home/h82/gpg.nix`: existing `programs.gpg` and `services.gpg-agent` configuration.
- `packages/gpg-tools.nix` and `scripts/pinentry-card`: the pinentry wrapper. It answers a card-PIN request directly from the `secret-tool` keyring when a PIN is cached, and otherwise delegates to `pinentry-qt`, falling back to `pinentry-curses` when neither `DISPLAY` nor `WAYLAND_DISPLAY` is set.
- `home/h82/kde/apps.nix`: precedent for referencing the `kdePackages` set.
- `flake.nix`: `checks.x86_64-linux.python3-runtime`, the closest existing user-package check.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: required reading before trusting a new repository check.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Add `kdePackages.kleopatra` to `home.packages` in `home/h82/default.nix`** (session-settled: user-directed — chosen over `environment.systemPackages` in `modules/nixos/`: keeps user-facing applications scoped to user `h82`, matching every other user application in this repository). Governs R1, R2.
- KTD2. **Take Kleopatra from the `kdePackages` (KF6/Qt6) set, not the top-level attribute.** The host runs Plasma 6 and `home/h82/kde/apps.nix` already references `pkgs.kdePackages.kconfig`; drawing from the same set keeps one Qt/KF runtime in the user profile. Verified present in the pinned nixpkgs as `kdePackages.kleopatra` 26.08.1. Governs R1, R2.
- KTD3. **Make no change to `home/h82/gpg.nix`.** Kleopatra talks to `gpg-agent` over the standard socket, so the configured `pinentry-card` wrapper already serves its prompts. That wrapper delegates to `pinentry-qt`, a graphical pinentry, so a desktop-launched Kleopatra gets a graphical prompt rather than a dead curses prompt with no controlling terminal. Governs R3, R4.
- KTD4. **Assert the package by store-output inspection, not by executing the binary.** The check resolves the Kleopatra derivation out of the evaluated user package set and asserts its `bin/kleopatra` and `share/applications/org.kde.kleopatra.desktop` exist. Kleopatra is a Qt GUI application, and running it inside a Nix build sandbox with no display or D-Bus session would make the check flaky for reasons unrelated to the declaration it guards. Governs R5.

### Assumptions

- The pinned `nixpkgs` (nixos-unstable, per `flake.lock`) continues to provide `kdePackages.kleopatra` building cleanly on `x86_64-linux`.
- The Plasma session exposes the Home Manager profile's `share/applications` through `XDG_DATA_DIRS`, as it already does for the other graphical packages in `home.packages`.

---

## Implementation Units

### U1. Declare Kleopatra in the Home Manager package set

- **Goal:** `kdePackages.kleopatra` is present in `home.packages` for user `h82`.
- **Requirements:** R1, R2, R3, R4
- **Dependencies:** None
- **Files:** `home/h82/default.nix`
- **Approach:**
  1. Insert `kdePackages.kleopatra` into the `home.packages` list, keeping the list's existing alphabetical order.
  2. Leave `home/h82/gpg.nix` unchanged, per KTD3.
- **Patterns to follow:** The existing `home.packages` entries in `home/h82/default.nix`; the `pkgs.kdePackages.*` reference style in `home/h82/kde/apps.nix`.
- **Test scenarios:**
  - Covers AE1. Happy path: the evaluated `home-manager.users.h82.home.packages` for the production host contains a derivation whose `pname` is `kleopatra`.
  - Integration: the bootstrap host configuration still evaluates and builds, since both hosts share `home/h82`.
- **Verification:** Both host toplevel builds succeed and the evaluated user package set contains Kleopatra.

### U2. Add a flake check guarding the declaration

- **Goal:** `nix flake check` fails if Kleopatra leaves the user package set or stops shipping its executable and desktop entry.
- **Requirements:** R5
- **Dependencies:** U1
- **Files:** `flake.nix`
- **Approach:**
  1. Add `kleopatra-gui` to `checks.${system}` in `flake.nix`.
  2. Resolve the Kleopatra derivation from `self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.home-manager.users.h82.home.packages` by `pname`, following the `python3-runtime` pattern but binding the derivation itself with `lib.findFirst (p: (p.pname or "") == "kleopatra") null userPackages`.
  3. Assert presence with an explicit failing branch that writes a reason to stderr and exits non-zero — never a `!`-negated command, which `set -e` does not fail on (see the mutation-testing learning). Emit that branch through `lib.optionalString` on the null case.
  4. Assert the resolved store output contains `bin/kleopatra` and `share/applications/org.kde.kleopatra.desktop`, emitting those assertions through `lib.optionalString` on the non-null case. Guarding every store-path interpolation this way is what makes the package-removal mutation fail *inside* the builder with the stated reason; interpolating the resolved path unconditionally would instead abort at evaluation with a null-coercion error before the builder runs, and an implementer seeing that red would record a false pass.
- **Patterns to follow:** `checks.${system}.python3-runtime` in `flake.nix` for the package-set lookup; `checks.${system}.ghostty-font` for asserting on evaluated configuration.
- **Execution note:** Mutation-test this check before trusting it, per `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`. One round per assertion class: remove the package from `home/h82/default.nix` and confirm the check turns red, then restore; point the desktop-entry assertion at a name the package does not ship and confirm it turns red, then restore. Record the rounds in the PR body.
- **Test scenarios:**
  - Covers AE1. Happy path: `nix build --no-link .#checks.x86_64-linux.kleopatra-gui` succeeds on the unmutated tree.
  - Failure path: with `kdePackages.kleopatra` removed from `home/h82/default.nix`, the check exits non-zero from inside the builder and prints which package is missing — not a Nix evaluation error.
  - Failure path: with the asserted desktop-entry filename changed to one the package does not ship, the check exits non-zero.
- **Verification:** `nix flake check` passes on the unmutated tree, and each mutation above turns the check red.

---

## Verification Contract

| Verification Command | Purpose | Expected Outcome |
| --- | --- | --- |
| `nix fmt -- --ci` | Formatting compliance | Clean exit 0 |
| `nix flake check` | All declared checks including `kleopatra-gui` | Clean exit 0 |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Production host build | Builds successfully |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap host build | Builds successfully |
| `nix build --no-link .#checks.x86_64-linux.kleopatra-gui` with U2's mutations applied | Proves the new check is a live guard, not decorative | Red on each mutation, green when restored |

AE2, AE3, and AE4 are hardware and session behaviors that a build-time check cannot reach. Report them separately as desktop verification per `docs/verification.md`, after the user rebuilds and logs into Plasma; do not run `nixos-rebuild switch` as validation.

---

## Definition of Done

- R1 through R5 are satisfied.
- `kdePackages.kleopatra` is declared in `home/h82/default.nix`, and `home/h82/gpg.nix` is unchanged.
- The `kleopatra-gui` check is registered in `flake.nix`, passes on the unmutated tree, and has been mutation-tested with the rounds recorded.
- `nix fmt -- --ci`, `nix flake check`, and both host toplevel builds pass.
- No exploratory or abandoned code remains in the diff.
