---
title: User Avatar Image (.face and .face.icon) - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# User Avatar Image (.face and .face.icon) - Plan

## Goal Capsule

- **Objective:** The `h82` account shows its own avatar picture, not the generic placeholder, in the SDDM login greeter, in KDE System Settings (Users), and in the Plasma session, on both hosts.
- **Means:** Commit the legacy avatar PNG to the repository once. Home Manager deploys it as `~/.face` and `~/.face.icon` (U2). A NixOS module installs it as `share/sddm/faces/h82.face.icon` in the system profile. SDDM's configured `FacesDir` points there, and the greeter reads it before any home-directory file (U3, KTD1). A flake check guards both deployments (U4).
- **Authority hierarchy:** [Issue #61](https://github.com/hyperlapse122/nix-config/issues/61) sets the outcome and the two home files. `AGENTS.md` governs module placement and check conventions. The captured checks learnings under `.compound-engineering/artifacts/solutions/best-practices/` govern how the check is written.
- **Stop conditions:** None. The change adds files and does not touch boot, secrets, or authentication.
- **Execution profile:** Lightweight, code.
- **Who finishes and ships:** `ce-work` implements the change and verifies it with builds and checks. Checking the greeter and settings on real hardware is a manual follow-up outside this plan's automated scope.

---

## Product Contract

### Summary

Port the avatar image from the legacy dotfiles (`home/dot_face`, with `home/symlink_dot_face.icon` pointing to it) into this flake, so the user avatar shows in the SDDM greeter and the KDE Plasma session.

### Problem Frame

The pre-NixOS dotfiles installed `~/.face` and a `~/.face.icon` symlink. This flake installs neither, so SDDM, System Settings, and the Plasma launcher all show the generic user icon.

### Requirements

- R1. `~/.face` and `~/.face.icon` are deployed in the `h82` home directory, and both have the legacy avatar's bytes.
- R2. The SDDM greeter shows the avatar for `h82`.
- R3. KDE System Settings (Users) and the Plasma session show the avatar.
- R4. Both hosts and their bootstrap variants carry the avatar.
- R5. `nix fmt -- --ci` and `nix flake check` pass, and all four host builds succeed.

### Scope Boundaries

- **Out of scope:** changing the avatar from the System Settings GUI and keeping that change. The avatar is declarative, and a GUI change is reset on the next rebuild or boot.
- **Out of scope:** avatars for any account other than `h82`.

### Key Decisions

- **Deploy `~/.face` and `~/.face.icon` through Home Manager `home.file`.** Governs R1, R3. (from issue #61, not settled in session: the issue proposes `home.file.".face".source` and `home.file.".face.icon".source` pointing at one asset. `ce-plan` adopts it. The alternative, an activation script that copies the file, was not chosen because `home.file` is the repository's usual way to place files.)

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Install the avatar as `h82.face.icon` in SDDM's `FacesDir` for the greeter. Home Manager alone cannot meet R2.** `/home/h82` is mode `700` (checked on the host), and the SDDM greeter runs as the `sddm` user, so it cannot open `~/.face.icon`. SDDM 0.21.0 (`src/greeter/UserModel.cpp`) checks three paths in order: `<FacesDir>/<user>.face.icon`, then `~/.face.icon`, then `/var/lib/AccountsService/icons/<user>`. On these hosts `FacesDir=/run/current-system/sw/share/sddm/faces` (from `/etc/sddm.conf.d/00-nixos.conf`), and that directory already holds `root.face.icon` from the system profile. A small derivation that provides `share/sddm/faces/h82.face.icon` (a copy of the asset), added to `environment.systemPackages`, puts the file there. It stays entirely in the Nix store, needs no write under `/var`, and SDDM checks it first. Rejected alternatives: a `systemd.tmpfiles.rules` `L+` link at `/var/lib/AccountsService/icons/h82`, which writes into accounts-daemon's state directory and competes with its icon writes; and `homeMode = "711"` on the user, which makes the whole home directory traversable just to show a picture.
- KTD2. **Put the system rule in a new focused module, `modules/nixos/desktop/user-avatar.nix`, imported by both hosts.** `desktop.nix` holds Plasma, SDDM, and fcitx5 settings. The avatar is a separate concern tied to the `h82` account, and `AGENTS.md` asks for one concern per module. Each `hosts/*/default.nix` lists its modules explicitly, so both host files import the new one. The import must not depend on `config.my.bootstrap`, because R4 covers the bootstrap variants.
- KTD3. **Keep one asset file at `home/h82/assets/face.png`, used by both Home Manager and NixOS.** The issue places the asset under `home/h82/`. The `.png` extension records the real format: the legacy file is a PNG, 49488 bytes, sha256 `2af691ff0c0b96a30f1c706f520af6e8c66d2509661e32e94359f62be9d8ee41`. The NixOS module refers to it by relative path, so the two deployments cannot drift apart.
- KTD4. **The legacy `dot_face` is a Git LFS pointer, so fetch the real bytes.** `https://media.githubusercontent.com/media/hyperlapse122/dotfiles/<default-branch>/home/dot_face` returns the image. Check the downloaded file against the LFS oid above before committing it. This repository does not use Git LFS, and a 49 KB file is fine to commit normally.
- KTD5. **The check reads what is actually built, not option values.** Following the captured learnings: for Home Manager, compare `.face` and `.face.icon` in the built `home-files` derivation byte for byte with the asset (`cmp`). For NixOS, compare `share/sddm/faces/h82.face.icon` in the built system profile (`config.system.path`) byte for byte with the asset. Both comparisons check file contents, so the check does not depend on the asset's store-path string. The check refers to the asset with the path literal `../home/h82/assets/face.png`, relative to `tests/user-avatar.nix`. Run the check on all four host configurations. Write every negative branch as `if ...; then echo >&2; exit 1; fi`, and keep interpolations behind guards, so a removal mutation fails inside the builder and not during evaluation.

### Assumptions

- SDDM shows avatars on these hosts. SDDM turns avatars off when there are more users than `DisableAvatarsThreshold`, which is not the case with one normal user. The hardware check in `docs/verification.md` confirms it.
- AccountsService gives System Settings `~/.face` as the icon when a user has no explicit `Icon=` entry. `accounts-daemon` runs as root, so it can read that file despite the `700` home directory. This also goes on the hardware checklist.
- The bootstrap variants carry the avatar too, because nothing in the issue excludes them.

---

## Implementation Units

### U1. Import the avatar asset

- **Goal:** Commit the legacy avatar PNG to `home/h82/assets/face.png`.
- **Requirements:** R1, R2 (KTD3, KTD4)
- **Dependencies:** none
- **Files:** `home/h82/assets/face.png` (new)
- **Approach:** Download the file from the LFS media URL (KTD4). Confirm it is 49488 bytes, that its sha256 matches the LFS oid, and that it starts with the PNG signature. Then commit it.
- **Test scenarios:** Test expectation: none. This unit adds a binary asset. U4 checks that it is deployed.
- **Verification:** `sha256sum home/h82/assets/face.png` prints the oid from KTD3.

### U2. Deploy `~/.face` and `~/.face.icon` through Home Manager

- **Goal:** Home Manager places the asset at both home paths.
- **Requirements:** R1, R3 (Key Decision above)
- **Dependencies:** U1
- **Files:** `home/h82/desktop/default.nix` (or a new `home/h82/desktop/avatar.nix` imported from it, whichever fits the existing layout better)
- **Approach:** Set `home.file.".face".source` and `home.file.".face.icon".source` to the asset. Both entries point at the asset directly, not one at the other: a symlink between two Home Manager links adds nothing. Either location puts the setting in the `desktop/` domain rather than the top-level `home/h82/default.nix`, matching the per-domain layout in `AGENTS.md`.
- **Test scenarios:** Covered by U4.
- **Verification:** U4 passes.

### U3. Add the SDDM faces module

- **Goal:** `/run/current-system/sw/share/sddm/faces/h82.face.icon` contains the asset on every host.
- **Requirements:** R2, R4 (KTD1, KTD2)
- **Dependencies:** U1
- **Files:** `modules/nixos/desktop/user-avatar.nix` (new), `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`, `hosts/MS-7D91/default.nix`
- **Approach:** The module adds to `environment.systemPackages` one small derivation (for example `pkgs.runCommand`) that installs `../../../home/h82/assets/face.png` as `share/sddm/faces/h82.face.icon` (KTD1). Add a short comment explaining why a home-directory file cannot serve the greeter (the `700` home directory), because otherwise the module looks redundant next to U2. Import the module next to `desktop.nix` in both host files.
- **Test scenarios:** Covered by U4.
- **Verification:** U4 passes. All four host builds succeed.

### U4. Add and register the `user-avatar` regression check

- **Goal:** Catch the avatar deployment being removed, retargeted, or diverging, on all four host configurations.
- **Requirements:** R1, R2, R4, R5 (KTD5)
- **Dependencies:** U2, U3
- **Files:** `tests/user-avatar.nix` (new), `flake.nix` (register the check)
- **Approach:**
  1. Follow the `tests/plasma-taskbar.nix` shape: a `{ pkgs, self }:` interface, and `pkgs.runCommand` with `set -x` and one `assertHost` helper called once per host.
  2. Bind the asset once in the test's `let` as the path literal `asset = ../home/h82/assets/face.png;` (KTD5). For each host, take `host.config.home-manager.users.h82.home-files` and check that `.face` and `.face.icon` exist and `cmp` equal to `${asset}`. Also check that `${host.config.system.path}/share/sddm/faces/h82.face.icon` exists and `cmp` equals `${asset}`.
  3. Register `user-avatar = import ./tests/user-avatar.nix { inherit pkgs self; };` in `flake.nix` next to `plasma-taskbar`.
- **Test scenarios:**
  - On the unmodified tree, all four hosts pass all three assertions.
  - Removal mutation: delete the `.face.icon` entry. The check fails inside the builder and names the host and the missing path.
  - Wiring mutation: drop the `user-avatar.nix` import from one host file. The check fails inside the builder for that host only.
  - Content mutation: point `.face` at a different file, for example any other file in the repository. The `cmp` assertion fails.
  - Target mutation: rename the installed file to `h83.face.icon`. The system-profile assertion fails.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.user-avatar` passes on the unmodified tree. Before calling U4 done, run each mutation above, confirm the failure happened inside the builder by reading `nix log`, and restore the tree.

---

## Verification Contract

| Command | Purpose |
| --- | --- |
| `nix fmt -- --ci` | Check formatting without making changes |
| `nix flake check` | Run all declared checks, including `user-avatar` |
| `nix build --no-link .#checks.x86_64-linux.user-avatar` | Run the new check alone, and rerun it for each mutation |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Host build |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap host build |
| `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel` | Host build |
| `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel` | Bootstrap host build |

## Definition of Done

- All four host builds succeed, and `nix fmt -- --ci` and `nix flake check` pass.
- The `user-avatar` check is registered, passes on the unmodified tree, and was shown to fail inside the builder for each U4 mutation.
- `docs/verification.md` lists a manual hardware check under "Hardware checks after installation": the SDDM greeter shows the avatar for `h82`, System Settings → Users shows it, and `/run/current-system/sw/share/sddm/faces/h82.face.icon` exists. Report this separately from the VM and build evidence.

## Sources & Research

- [Issue #61](https://github.com/hyperlapse122/nix-config/issues/61): the outcome, the proposed `home.file` entries, and the acceptance criteria.
- `hyperlapse122/dotfiles` `home/dot_face` (a Git LFS pointer; oid `2af691ff…ee41`, size 49488) and `home/symlink_dot_face.icon` (a link to `.face`), read through `gh api`. The media URL returned a PNG with the matching hash.
- Host inspection: `/home/h82` has mode `700`; `/etc/sddm.conf.d/00-nixos.conf` sets `FacesDir=/run/current-system/sw/share/sddm/faces`, which already holds `root.face.icon`. This is the evidence behind KTD1.
- [SDDM 0.21.0 `src/greeter/UserModel.cpp`](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/UserModel.cpp): the avatar lookup order `FacesDir/<user>.face.icon` → `~/.face.icon` → AccountsService `icons/<user>` (KTD1).
- `modules/nixos/desktop/desktop.nix`, and `hosts/*/default.nix` for the module imports (KTD2).
- `tests/plasma-taskbar.nix` and the `zsh-prezto` check in `flake.nix`, the existing patterns for checks that read Home Manager output.
- `.compound-engineering/artifacts/solutions/best-practices/nix-check-reads-option-value-not-materialized-output.md`, `mutation-testing-reveals-decorative-nix-check-assertions.md`, `unguarded-derivation-interpolation-defeats-nix-check-mutation-testing.md` (KTD5).
