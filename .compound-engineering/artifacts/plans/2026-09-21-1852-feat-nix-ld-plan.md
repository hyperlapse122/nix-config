---
title: Enable nix-ld for Dynamically Linked Binaries - Plan
type: feat
date: 2026-09-21
topic: nix-ld
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** Enable `programs.nix-ld` system-wide on ThinkPad X1 Carbon Gen 11 so that dynamically linked ELF binaries (such as those downloaded at runtime by `bunx tokscale@latest`) find an FHS interpreter at `/lib64/ld-linux-x86-64.so.2` and link against baseline shared libraries.
- **Means:** Create `modules/nixos/nix-ld.nix` configuring `programs.nix-ld.enable = true` and `programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib openssl ];`. Import it into `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11. Base system package changes outside nix-ld and desktop customization are non-goals.
- **Open Blockers:** None.

---

## Product Contract

*Product Contract preservation: Direct planning bootstrap from GitHub issue #17.*

### Summary

Create a dedicated NixOS system module `modules/nixos/nix-ld.nix` enabling `programs.nix-ld` with a baseline set of libraries (`stdenv.cc.cc.lib`, `zlib`, `openssl`), import it into the host configuration, add a regression check `tests/nix-ld.nix` verified with mutation testing, and document verification steps.

### Problem Frame

NixOS does not follow the Filesystem Hierarchy Standard (FHS) and lacks `/lib64/ld-linux-x86-64.so.2` by default. When tools like `bunx` or `npx` download and execute prebuilt ELF binaries at runtime (e.g., `bunx tokscale@latest`), the dynamic linker is missing, causing `no such file or directory` errors on existing executables. Enabling `programs.nix-ld` provisions the standard dynamic linker symlink via systemd-tmpfiles and points it to `nix-ld`, which intercepts executions and loads libraries from `/run/current-system/sw/share/nix-ld/lib`.

### Key Decisions

- **KD1: Isolate nix-ld configuration in `modules/nixos/nix-ld.nix`** (session-settled: user-directed — chosen over editing `modules/nixos/base.nix`: adheres to repository guidelines that each module remains focused on one concern). Governs R1, R2, R3.
- **KD2: Include `stdenv.cc.cc.lib`, `zlib`, and `openssl` in `programs.nix-ld.libraries`** (session-settled: user-directed — chosen over relying solely on nixpkgs defaults: guarantees standard C/C++ runtime, compression, and crypto libraries required by runtime tools like tokscale). Governs R2.
- **KD3: Import `modules/nixos/nix-ld.nix` in `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`** (session-settled: user-directed — chosen over conditional per-host toggles: ensures both production and bootstrap builds evaluate nix-ld consistently). Governs R1.
- **KD4: Add dedicated flake check `tests/nix-ld.nix` verified with mutation testing** (session-settled: user-directed — chosen over inline check in flake.nix: keeps flake.nix concise, aligns with `tests/agent-memory.nix` and `tests/keyd-remap.nix`, and follows mutation testing principles from `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`). Governs R4.

### Requirements

**System Module & Host Configuration**

- R1. `programs.nix-ld.enable` evaluates to `true` on both `ThinkPad-X1-Carbon-Gen-11` and `ThinkPad-X1-Carbon-Gen-11-bootstrap`.
- R2. `programs.nix-ld.libraries` on the host contains `stdenv.cc.cc.lib`, `zlib`, and `openssl`.
- R3. Module `modules/nixos/nix-ld.nix` contains only `programs.nix-ld` configuration, maintaining single-concern separation.

**Automated Regression Testing**

- R4. Flake check `checks.${system}.nix-ld` asserts:
  - `programs.nix-ld.enable` is `true` for production and bootstrap configurations.
  - Required libraries (`stdenv.cc.cc.lib`, `zlib`, `openssl`) are present in `programs.nix-ld.libraries`.
  - Assertions are non-decorative, use `set -x` for debug tracing, avoid negated commands under `set -e`, and exit 1 on violation.

**Documentation**

- R5. `docs/verification.md` lists the `nix-ld` check under repository checks and adds a post-installation hardware checklist item for `bunx tokscale@latest`.

### Acceptance Examples

- AE1. Module evaluation
  - **Covers R1, R2, R3.**
  - **Given:** NixOS host configuration `ThinkPad-X1-Carbon-Gen-11`.
  - **When:** Evaluated via `nix eval`.
  - **Then:** `config.programs.nix-ld.enable` is `true`, and `config.programs.nix-ld.libraries` includes gcc/stdenv, zlib, and openssl packages.

- AE2. Flake check execution and mutation resilience
  - **Covers R4.**
  - **Given:** `tests/nix-ld.nix` imported in `checks.${system}.nix-ld`.
  - **When:** `nix build --no-link .#checks.x86_64-linux.nix-ld` runs.
  - **Then:** Check passes cleanly. If an assertion is inverted or an option forced false via mutation, the check fails with exit code 1.

- AE3. System builds
  - **Covers R1.**
  - **Given:** Production and bootstrap host configurations.
  - **When:** `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` and `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` run.
  - **Then:** Both derivations evaluate and build successfully.

### Scope Boundaries

- Manual `patchelf` invocations or wrapping binaries in ad-hoc FHS environments are excluded.
- Physical hardware verification (`bunx tokscale@latest` on the real laptop) cannot be performed inside the build sandbox; it is recorded as a post-installation checklist item per `docs/verification.md`.

### Sources / Research

- GitHub Issue #17: `feat(nixos): enable nix-ld for dynamically linked binaries`.
- `.compound-engineering/artifacts/solutions/best-practices/mutation-testing-reveals-decorative-nix-check-assertions.md`: Mutation testing guidelines for Nix flake checks.
- `nixpkgs/nixos/modules/programs/nix-ld.nix`: Upstream nix-ld module implementation and default libraries.
- `tests/agent-memory.nix`, `tests/keyd-remap.nix`: Established patterns for standalone Nix flake check modules.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Create `modules/nixos/nix-ld.nix` with declarative `programs.nix-ld` settings** (session-settled: user-directed — chosen over modifying base.nix: preserves single concern per module). Governs R1, R2, R3.
- KTD2. **Declare baseline libraries `stdenv.cc.cc.lib`, `zlib`, `openssl` in `programs.nix-ld.libraries`** (session-settled: user-directed — chosen over empty list: provides runtime dynamic linkage dependencies). Governs R2.
- KTD3. **Import `modules/nixos/nix-ld.nix` in `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`** (session-settled: user-directed — ensures both normal and bootstrap configurations inherit nix-ld). Governs R1.
- KTD4. **Implement `tests/nix-ld.nix` and register `checks.${system}.nix-ld` in `flake.nix`** (session-settled: user-directed — follows mutation testing solution). Governs R4.

### Technical Design

The implementation adds a standalone NixOS module `modules/nixos/nix-ld.nix` that sets:

```nix
{ pkgs, ... }:
{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
    ];
  };
}
```

This is imported in `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
A new check `tests/nix-ld.nix` evaluates both `self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11` and `self.nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap`, asserting `enable == true` and checking that library packages contain the expected names. It runs in a sandbox derivation with `set -x` and explicit `if` branches for failure reporting.

### Assumptions

- Upstream `nixpkgs` includes `programs.nix-ld` on `x86_64-linux` and correctly configures `/lib64/ld-linux-x86-64.so.2` via systemd-tmpfiles when enabled.

---

## Implementation Units

### U1. Create `modules/nixos/nix-ld.nix`

- **Goal:** Create a dedicated NixOS module for `nix-ld`.
- **Requirements:** R1, R2, R3
- **Dependencies:** None
- **Files:** `modules/nixos/nix-ld.nix`
- **Approach:**
  1. Create `modules/nixos/nix-ld.nix` setting `programs.nix-ld.enable = true;` and `programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib openssl ];`.
- **Patterns to follow:** `modules/nixos/fonts.nix`.
- **Test scenarios:**
  - Happy path: Module evaluates cleanly with NixOS module system.
- **Verification:** Nix syntax check / evaluation.

### U2. Import `nix-ld.nix` in host configuration

- **Goal:** Enable `nix-ld` on `ThinkPad-X1-Carbon-Gen-11` (and bootstrap).
- **Requirements:** R1, R3
- **Dependencies:** U1
- **Files:** `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`
- **Approach:**
  1. Add `../../modules/nixos/nix-ld.nix` to `imports` in `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
- **Patterns to follow:** Existing imports in `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
- **Test scenarios:**
  - Happy path: `nix eval .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.programs.nix-ld.enable` returns `true`.
  - Bootstrap: `nix eval .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.programs.nix-ld.enable` returns `true`.
- **Verification:** Both host configurations evaluate `programs.nix-ld.enable` as `true`.

### U3. Create `tests/nix-ld.nix` and register check in `flake.nix`

- **Goal:** Add a non-decorative regression check asserting `nix-ld` configuration and verify with mutation testing.
- **Requirements:** R4
- **Dependencies:** U1, U2
- **Files:** `tests/nix-ld.nix`, `flake.nix`
- **Approach:**
  1. Write `tests/nix-ld.nix` accepting `{ pkgs, self }`.
  2. Inspect evaluated `host.config.programs.nix-ld.enable`, `bootstrapHost.config.programs.nix-ld.enable`, and the `libraries` list.
  3. Validate using explicit `if [ "$val" != "true" ]; then echo >&2; exit 1; fi`.
  4. Register `checks.${system}.nix-ld = import ./tests/nix-ld.nix { inherit pkgs self; };` in `flake.nix`.
  5. Perform mutation testing: deliberately break each assertion class and confirm failure before restoring.
- **Patterns to follow:** `tests/agent-memory.nix`, `tests/keyd-remap.nix`.
- **Test scenarios:**
  - Happy path: `nix build --no-link .#checks.x86_64-linux.nix-ld` passes on clean tree.
  - Mutation 1: Setting `programs.nix-ld.enable = false` in `modules/nixos/nix-ld.nix` causes the check to fail.
  - Mutation 2: Removing `zlib` from `programs.nix-ld.libraries` causes the check to fail.
- **Verification:** Baseline passes; mutations fail; restoration passes.

### U4. Update `docs/verification.md`

- **Goal:** Document the new repository check and post-installation hardware verification item.
- **Requirements:** R5
- **Dependencies:** U3
- **Files:** `docs/verification.md`
- **Approach:**
  1. Add description of `nix-ld` check in the Repository checks section of `docs/verification.md`.
  2. Add a hardware checklist item: "Confirm `bunx tokscale@latest` runs without `patchelf` or FHS wrapper errors."
- **Patterns to follow:** Existing check entries in `docs/verification.md`.
- **Test scenarios:**
  - Documentation integrity and link checks.
- **Verification:** View file and check formatting.

---

## Verification Contract

| Verification Command | Purpose | Expected Outcome |
| --- | --- | --- |
| `nix fmt -- --ci` | Formatting compliance | Clean exit 0 |
| `nix flake check` | All flake checks including `nix-ld` | Clean exit 0 |
| `nix build --no-link .#checks.x86_64-linux.nix-ld` | Direct check build | Builds successfully |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel` | Host system build check | Builds successfully |
| `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel` | Bootstrap system build check | Builds successfully |

---

## Definition of Done

- Requirements R1, R2, R3, R4, and R5 are satisfied.
- `modules/nixos/nix-ld.nix` is created and imported into `hosts/ThinkPad-X1-Carbon-Gen-11/default.nix`.
- Flake check `nix-ld` is registered in `flake.nix` and mutation tested.
- `nix flake check` passes.
- Both production and bootstrap toplevel builds succeed.
- `docs/verification.md` is updated.
- Code conforms to repository formatting guidelines (`nix fmt -- --ci`).
