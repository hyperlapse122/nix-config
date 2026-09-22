---
title: Add Claude Desktop for Linux - Plan
type: feat
date: 2026-09-22
topic: claude-desktop
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

## Goal Capsule

- **Objective:** User `h82` has Claude Desktop for Linux installed and executable from the desktop environment across hosts, with hardware virtualization and kernel modules configured to support Cowork.
- **Means:** Package Claude Desktop from Anthropic's official Debian package with ELF binary patching via `autoPatchelfHook`, asar firmware/virtiofsd path patching, add it to `home.packages` for user `h82`, add `kvm` group and `vhost_vsock` kernel module in `modules/nixos/base.nix`, and guard with regression checks in `flake.nix`.
- **Product Authority:** User `h82` on ThinkPad X1 Carbon Gen 11 and MS-7D91 desktop.
- **Open Blockers:** None.

---

## Product Contract

### Summary

Install Claude Desktop for Linux (Anthropic's official desktop application) as a Home Manager package for user `h82`, complete with desktop launcher (`com.anthropic.Claude.desktop`), Wayland Ozone compatibility flags, system virtualization support (`kvm` group membership and `vhost_vsock` kernel module for the Cowork VM engine), and regression checks in `flake.nix`.

### Problem Frame

Anthropic released the official beta of Claude Desktop for Linux (distributed as a Debian `.deb` package at `https://code.claude.com/docs/en/desktop-linux`). The NixOS environment currently provides CLI agent tools (`claude-code`, `antigravity-cli`), but lacks the graphical desktop interface for Claude (with tabs for Chat, Cowork VM dispatch, visual diffs, and live preview). Installing and packaging Claude Desktop declaratively on NixOS requires wrapping the Electron binary, providing needed shared libraries, patching hardcoded Debian firmware paths for Cowork, and enabling KVM permissions and the `vhost_vsock` kernel module.

### Key Decisions

- Package Claude Desktop from Anthropic's official Debian package repository (`https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_2.2553.1_amd64.deb`) using `autoPatchelfHook`, `makeWrapper`, and `asar` path patching (session-settled: user-directed — chosen over third-party community repackagings: uses the official Anthropic release binary and assets directly). Governs R1, R2.
- Patch `app.asar` during derivation build to redirect hardcoded Debian OVMF firmware paths (`/usr/share/OVMF/OVMF_CODE*.fd`) and `virtiofsd` paths to Nix store paths (`${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd` and `${pkgs.virtiofsd}/bin/virtiofsd`), and suffix `PATH` with `xdg-utils`, `qemu_kvm`, and `virtiofsd` (session-settled: user-directed — ensures Cowork virtualization tab functions on NixOS without requiring Debian filesystem paths). Governs R2.
- Configure user `h82` with `kvm` in `users.users.h82.extraGroups` and `vhost_vsock` in `boot.kernelModules` in `modules/nixos/base.nix` (session-settled: user-directed — satisfies the official Linux Cowork requirements for `/dev/kvm` and `/dev/vhost-vsock`). Governs R3.
- Register a flake check `claude-desktop` in `flake.nix` with derivation guards that protect against removal and verify binaries, desktop entry, `kvm` group, and `vhost_vsock` kernel module (session-settled: user-directed — ensures mutation testing fails inside the builder with explicit diagnostic messages). Governs R4, R5.

### Requirements

**Availability & Execution**

- R1. User `h82` has Claude Desktop installed through `home.packages`, providing the `claude-desktop` executable on PATH and the `com.anthropic.Claude.desktop` desktop launcher with Wayland Ozone platform hint flags.
- R2. Claude Desktop packaging provides patched references to `OVMFFull.fd` and `virtiofsd`, and includes `qemu_kvm` on PATH for Cowork support.

**System Virtualization**

- R3. NixOS hosts declare `kvm` in `users.users.h82.extraGroups` and `vhost_vsock` in `boot.kernelModules` in `modules/nixos/base.nix`.

**Flake Checks & Regression Guard**

- R4. A flake check `claude-desktop` in `flake.nix` asserts that user `h82` packages contain `claude-desktop` with executable `bin/claude-desktop` and desktop entry `share/applications/com.anthropic.Claude.desktop`.
- R5. The flake check `claude-desktop` asserts that `kvm` is present in `users.users.h82.extraGroups` and `vhost_vsock` is present in `boot.kernelModules`.

### Acceptance Examples

- AE1. Claude Desktop application availability
  - **Covers R1, R4.**
  - **Given:** A built home-manager environment for user `h82`.
  - **When:** `claude-desktop` is located in the user profile.
  - **Then:** Executable `bin/claude-desktop` runs (`--version` reports `2.2553.1`) and desktop file `share/applications/com.anthropic.Claude.desktop` is present.

- AE2. Cowork virtualization support
  - **Covers R2, R3, R5.**
  - **Given:** Evaluated NixOS configuration for ThinkPad and MS-7D91.
  - **When:** Checking `config.users.users.h82.extraGroups` and `config.boot.kernelModules`.
  - **Then:** `"kvm"` is an element of `extraGroups` and `"vhost_vsock"` is an element of `kernelModules`.

- AE3. Regression check builder failure on mutation
  - **Covers R4, R5.**
  - **Given:** A mutated configuration where `claude-desktop` is removed from `home/h82/default.nix`.
  - **When:** `nix build --no-link .#checks.x86_64-linux.claude-desktop` is run.
  - **Then:** The check fails inside the builder with an explicit missing package message.

### Scope Boundaries

- Focuses on packaging the official Anthropic Debian release of Claude Desktop and configuring system prerequisites for Linux beta features (Chat and Cowork).
- Does not modify browser settings or third-party web wrapper apps.
- Does not alter unfree predicate in nixpkgs (`allowUnfree = true` is already configured in base and flake).

### Sources / Research

- Anthropic Claude Desktop Linux documentation: `https://code.claude.com/docs/en/desktop-linux`
- Anthropic APT repository package index: `https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages`
- Package source: `https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_2.2553.1_amd64.deb`
- Existing packages: `packages/orca.nix`, `home/h82/default.nix`, `flake.nix`.

---

## Planning Contract

### Key Technical Decisions

- KTD1: Package `claude-desktop` in `packages/claude-desktop.nix` accepting `{ pkgs }`. Use `stdenv.mkDerivation` with `dpkg`, `autoPatchelfHook`, `makeWrapper`, and `asar`.
- KTD2: Patch `app.asar` in `claude-desktop.nix` to replace `/usr/share/OVMF/OVMF_CODE*.fd` with `${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd` and `/usr/libexec/virtiofsd` with `${pkgs.virtiofsd}/bin/virtiofsd`. Remove `compile-cache` when repacking so V8 executes the modified code. Wrap `bin/claude-desktop` with `gsettings-desktop-schemas`, `gtk3`, `xdg-utils`, `qemu_kvm`, and `virtiofsd` on PATH.
- KTD3: Add `(import ../../packages/claude-desktop.nix { inherit pkgs; })` to `home.packages` in `home/h82/default.nix`, and expose `packages.${system}.claude-desktop` in `flake.nix`.
- KTD4: Add `"kvm"` to `users.users.h82.extraGroups` and `"vhost_vsock"` to `boot.kernelModules` in `modules/nixos/base.nix`.
- KTD5: Register `claude-desktop` regression check in `flake.nix` asserting package presence, executable, desktop file, `kvm` group, and `vhost_vsock` kernel module.

### Sequencing and Dependencies

- U1: Create `packages/claude-desktop.nix`.
- U2: Update `modules/nixos/base.nix` to add `kvm` group and `vhost_vsock` kernel module.
- U3: Update `home/h82/default.nix` and `flake.nix` to declare package and register check.
- U4: Full verification, formatting, mutation testing, and system builds.

---

## Implementation Units

### U1. Create Claude Desktop package derivation

- **Goal:** Create `packages/claude-desktop.nix` containing the derivation for Claude Desktop Linux.
- **Files:** `packages/claude-desktop.nix`
- **Approach:** Use `dpkg` to extract deb archive, `autoPatchelfHook` with Electron libraries, `asar` to patch Cowork firmware paths, and `makeWrapper` with Wayland Ozone flags, GSettings schemas, and PATH suffix.
- **Verification:** Evaluates and builds cleanly via `packages/claude-desktop.nix`.

### U2. Configure system virtualization prerequisites

- **Goal:** Add `kvm` group to user `h82` and `vhost_vsock` module to `boot.kernelModules`.
- **Files:** `modules/nixos/base.nix`
- **Approach:** Add `"kvm"` to `users.users.h82.extraGroups` and `"vhost_vsock"` to `boot.kernelModules`.
- **Verification:** Evaluates cleanly in NixOS host configurations.

### U3. Integrate package in Home Manager and Flake

- **Goal:** Add `claude-desktop` to `home/h82/default.nix`, expose it in `flake.nix` `packages`, and register `checks.x86_64-linux.claude-desktop`.
- **Files:** `home/h82/default.nix`, `flake.nix`
- **Approach:** Add package import to `home.packages` and `packages.${system}`, and write regression check in `flake.nix`.
- **Verification:** `nix build --no-link .#checks.x86_64-linux.claude-desktop` succeeds.

### U4. Full verification, formatting, and mutation testing

- **Goal:** Run `nix fmt`, check flake checks, run mutation test on the new check, and build all host toplevels.
- **Files:** none
- **Verification:**
  - `nix fmt -- --ci`
  - `nix flake check`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`
  - Mutation test: verify check fails if `claude-desktop` is omitted.

---

## Verification Contract

- Check `claude-desktop`: `nix build --no-link .#checks.x86_64-linux.claude-desktop`
- Repository flake checks: `nix flake check`
- Tree formatting: `nix fmt -- --ci`
- Host toplevel builds:
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.ThinkPad-X1-Carbon-Gen-11-bootstrap.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91.config.system.build.toplevel`
  - `nix build --no-link .#nixosConfigurations.MS-7D91-bootstrap.config.system.build.toplevel`

---

## Definition of Done

- `packages/claude-desktop.nix` is created and builds cleanly with `autoPatchelfHook` and asar patching.
- `modules/nixos/base.nix` adds `kvm` to `users.users.h82.extraGroups` and `vhost_vsock` to `boot.kernelModules`.
- `home/h82/default.nix` declares `claude-desktop` in `home.packages`.
- `flake.nix` exposes `claude-desktop` in `packages.${system}` and registers regression check `claude-desktop`.
- Flake check `claude-desktop` passes on clean tree and fails inside builder upon mutation.
- `nix fmt -- --ci` passes.
- `nix flake check` passes.
- All four host toplevels build without error.
