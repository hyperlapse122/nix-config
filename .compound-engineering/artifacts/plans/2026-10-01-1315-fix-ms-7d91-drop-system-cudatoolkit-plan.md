---
title: Drop MS-7D91 System CUDA Toolkit - Plan
type: fix
date: 2026-10-01
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Drop MS-7D91 System CUDA Toolkit - Plan

## Goal Capsule

- **Objective:** `nixos-rebuild switch` on the MS-7D91 desktop succeeds again, and the GPU still works for the desktop session and for Podman containers.
- **Means:** remove `cudaPackages.cudatoolkit` from the host's system packages (KTD1).
- **Authority:** the Requirements below win on behavior. KTD1 wins on mechanism.
- **Stop conditions:** stop and report if removing the package does not remove every CUDA derivation from the MS-7D91 closure, or if any other output stops building.
- **Execution profile:** one small Nix edit, then evaluation and build checks. No hardware switch is run as validation.
- **Finishing:** the implementer verifies and ships the change. The user runs `nrs` on the hardware.

## Product Contract

### Summary

Remove the system-wide CUDA toolkit from MS-7D91 so its system closure builds again. The NVIDIA driver, its settings, and the NVIDIA container toolkit stay as they are. When CUDA development tools are needed, they come from a container image. `nix shell` also works once the locked nixpkgs carries an upstream fix. Until then, the system `nixpkgs` registry points at the same broken revision.

### Problem Frame

The flake.lock update to nixpkgs `b4fd65b` (2026-09-29) broke the MS-7D91 system build. `cuda_cuxxfilt` fails in `multiple-outputs.sh` line 214 with `bin include: invalid variable name`. The locked stdenv reads the CUDA redist builder's `propagatedBuildOutputs` value `"bin include"` as a single output name. This happens with every CUDA version: `cudaPackages_13` (13.3) fails the same way as the default 12.9. The only path from the system to CUDA is `cudaPackages.cudatoolkit` in `hosts/MS-7D91/hardware.nix`, which pulls `cuda-merged` into `system-path`.

### Requirements

**Build**

- R1. The MS-7D91 production and bootstrap configurations build with the current `flake.lock`.
- R2. The MS-7D91 system closure contains no CUDA redist derivation (`cuda-merged`, `cuda12.*`, `cuda13.*`).

**Preserved behavior**

- R3. The NVIDIA proprietary driver, `hardware.nvidia.*` settings, `services.xserver.videoDrivers`, and `hardware.nvidia-container-toolkit.enable` stay unchanged, so GPU access for containers through CDI keeps working.
- R4. Every other `nixosConfigurations` output and `nix flake check` keep passing.

### Key Decisions

- **Remove the system toolkit instead of changing the CUDA version.** Governs R1, R2. (session-settled: user-directed — chosen over bumping to `cudaPackages_13` with an overlay workaround, reverting `flake.lock`, or bumping to CUDA 13 alone: CUDA 13.3 `cuda_cuxxfilt` fails with the same stdenv error, so no CUDA version builds on the locked nixpkgs.)
- **Keep the driver stack and `flake.lock` as they are.** Governs R3, R4. (session-settled: user-directed — chosen over reverting `flake.lock`: the lock stays current, and CUDA toolkit use moves to `nix shell` or containers.)

### Scope Boundaries

- An overlay that patches `propagatedBuildOutputs` for CUDA redist packages is not built. If the user later needs host-level CUDA tools before upstream fixes the regression, that would be a separate change.
- Reverting or pinning `flake.lock` is not done.
- Upstream nixpkgs reporting or fixing is out of scope.
- The MS-7D91 desktop plan's R9 asks for "CUDA libraries and NVIDIA container toolkit (CDI)" for rootless Podman. The driver package and the container toolkit's CDI spec provide the runtime libraries containers need, so R9 stays covered without the host toolkit.

### Success Criteria

- The `nrs` failure from `cuda12.9-cuda_cuxxfilt` no longer appears for the current lock.

## Planning Contract

### Key Technical Decisions

- KTD1. **Delete the `environment.systemPackages` block in `hosts/MS-7D91/hardware.nix`.** It holds only `cudaPackages.cudatoolkit`, so the whole block goes rather than an empty list. Once the block is gone, `pkgs` is no longer used in that file, so the module arguments shrink to `{ lib, ... }`. Implements the Key Decisions above (governs R1, R2, R3).

### Assumptions

- Nothing else in the MS-7D91 closure depends on a CUDA redist derivation. A repository search finds `cudaPackages` only in `hosts/MS-7D91/hardware.nix`. The closure check in the Verification Contract confirms this.
- The user has no host-side workflow that needs `nvcc` on `PATH` permanently. The user accepted moving that use to `nix shell` or containers.
- `nix shell nixpkgs#cudaPackages.cudatoolkit` fails the same way while the regression stands. The NixOS default `nixpkgs.flake.setFlakeRegistry = true` pins the system `nixpkgs` registry to the locked input. Containers are the working path until a fixed nixpkgs is locked.

## Implementation Units

### U1. Remove the system CUDA toolkit from MS-7D91

- **Goal:** MS-7D91's system closure no longer pulls in `cuda-merged`.
- **Requirements:** R1, R2, R3, KTD1.
- **Dependencies:** none.
- **Files:** `hosts/MS-7D91/hardware.nix`.
- **Approach:**
  1. Delete the `environment.systemPackages` block.
  2. Drop the now-unused `pkgs` module argument.
  3. Leave every `hardware.nvidia*` and `services.xserver.videoDrivers` line untouched.
- **Patterns to follow:** `hosts/*/hardware.nix` module shape. Let `nix fmt` set the layout.
- **Test expectation:** none -- pure host configuration with no new behavior. The build and closure checks in the Verification Contract are the proof.
- **Execution note:** this is configuration only. Prove it with evaluation, build, and closure checks, not new tests.
- **Verification:** the MS-7D91 toplevel builds, its closure has no CUDA redist paths, and the NVIDIA options evaluate to the same values as before.

## Verification Contract

| Gate | Command | Proves |
|---|---|---|
| Formatting | `nix fmt -- --ci` | Layout matches `nixfmt-tree` |
| Flake checks | `nix flake check` | R4 |
| All hosts build | The `nixosConfigurations` build loop in `AGENTS.md`, for production and bootstrap outputs | R1, R4 |
| No CUDA in closure | `nix path-info -r` on the MS-7D91 toplevel, filtered for `cuda-merged`, `cuda12`, `cuda13` | R2 |
| Driver stack unchanged | `nix eval` of `hardware.nvidia.package.version`, `hardware.nvidia-container-toolkit.enable`, and `services.xserver.videoDrivers` for MS-7D91, compared with the base commit | R3 |

Hardware verification (`nrs` on MS-7D91, then `nvidia-smi` and a GPU container smoke test) is reported separately from these checks, per `docs/verification.md`.

## Definition of Done

- U1 is landed, and every Verification Contract gate passes on the branch.
- The MS-7D91 closure filter returns no paths.
- The diff touches only `hosts/MS-7D91/hardware.nix` and this plan, with no leftover experimental edits.
